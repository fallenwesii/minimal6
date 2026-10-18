#!/usr/bin/env python3
"""
Wallpaper Switcher — GTK3 horizontal carousel wallpaper picker for SwayFX.

Native floating window (app_id="wallpaper-picker"): thumbnail carousel,
Left/Right keys or mouse scroll to navigate, Esc closes, Enter / center
click applies. Search is keystroke-driven and matches the file name
(no visible search widget). The selected card shows a taller 200x250
thumbnail with a matugen border baked in — that size jump is the carousel's
"grow" animation feel.

Responsibilities are split across two entry points:

  wallpaper-switcher.sh    launcher: makes sure ~/.cache/wallpaper-picker
                           exists and hands --generate-cache to sway
                           (so it survives the UI closing)
  wallpaper-switcher.py    UI mode (default): shows the picker.
  wallpaper-switcher.py --generate-cache
                          rebuilds missing/stale thumbnails, per-image
                          matugen colors and the activated thumbnails,
                          then exits — this is what sway runs detached.

Both entry points live in this file but never share its expensive part:
the generator exits before the GTK import (pygobject + libgtk costs ~0.8s,
and the launcher spawns a generator on every keypress — that import used
to be paid a second time, stealing CPU from the picker the user waits on).
Each entry point also holds its own exclusive flock, so repeated keypresses
can neither stack cache generators nor open two windows.
"""

import fcntl
import json
import os
import random
import shlex
import shutil
import signal
import subprocess
import sys
import time

PID_FILE = os.path.expanduser("~/.cache/wallpaper-picker.pid")
CACHE_DIR = os.path.expanduser("~/.cache/wallpaper-picker")
GEN_LOCK = os.path.join(CACHE_DIR, ".generate.lock")  # held by one cache pass
UI_LOCK = os.path.join(CACHE_DIR, ".ui.lock")        # held by the open window
_ui_lock_fd = None  # keeps the UI lock alive for this process's lifetime
APPLY_SCRIPT = os.path.expanduser("~/.config/sway/scripts/apply-wallpaper.sh")
COLORS_CSS = os.path.expanduser("~/.config/wofi/colors.css")

WALLPAPER_DIRS = ("~/Pictures/wallpapers", "~/Pictures/wallpaper")
SUPPORTED_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".gif")

# --- UI knobs -----------------------------------------------------------
WINDOW_RADIUS = 30    # window corner roundness (GTK paints it; SwayFX
                      # corner_radius in the window rules controls the rest)
THUMB_RADIUS = 15     # rounded-corner mask baked into cached thumbnails
THUMB_SIZE = 200      # side (inactive) thumbnails: 200x200
ACTIVE_W = 200        # selected thumbnail: 200x250 — same width as the
ACTIVE_H = 250        # side thumbs but 50px taller, so the active card
                      # grows out top and bottom (the "animation" feel)
CARD_SPACING = 14
INACTIVE_OPACITY = 0.55
CACHE_RETRY_MS = 2000  # re-check for late-arriving thumbs (set by first run)
CACHE_RETRIES = 8      # give up after ~16s if sway's generator never lands


# ---------------------------------------------------------------------------
# Paths / wallpaper listing
# ---------------------------------------------------------------------------

def wallpaper_dir():
    for raw in WALLPAPER_DIRS:
        d = os.path.expanduser(raw)
        if os.path.isdir(d) and any(f.lower().endswith(SUPPORTED_EXTS) for f in os.listdir(d)):
            return d
    return os.path.expanduser(WALLPAPER_DIRS[0])


def list_wallpapers(wall_dir, shuffle=False):
    if not os.path.isdir(wall_dir):
        return []
    files = [
        os.path.join(wall_dir, f)
        for f in os.listdir(wall_dir)
        if f.lower().endswith(SUPPORTED_EXTS) and os.path.isfile(os.path.join(wall_dir, f))
    ]
    if shuffle:
        random.shuffle(files)
    return files


def thumb_path(wall_path):
    return os.path.join(CACHE_DIR, os.path.basename(wall_path) + ".png")


def active_path(wall_path):
    return os.path.join(CACHE_DIR, os.path.basename(wall_path) + ".active.png")


def color_path(wall_path):
    return os.path.join(CACHE_DIR, os.path.basename(wall_path) + ".colors")


def is_stale(source, cache):
    """True when the cache file is missing or older than its source."""
    try:
        return os.path.getmtime(source) > os.path.getmtime(cache)
    except OSError:
        return True


# ---------------------------------------------------------------------------
# Single-instance / toggle behavior
# ---------------------------------------------------------------------------

def pid_is_picker(pid):
    """True only when pid really is the picker window.

    The cache generator runs this same script, so a recycled pid could
    otherwise be mistaken for the open UI and get SIGTERMed.
    """
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read().decode("utf-8", errors="ignore")
    except OSError:
        return False
    return "wallpaper-switcher.py" in cmdline and "--generate-cache" not in cmdline


def signal_open_picker():
    """SIGTERM the picker that already holds the UI lock.

    The winner writes PID_FILE just after taking the flock, so a toggle that
    lands in the same instant can read the file before that write and miss
    the window entirely (the press then appears to do nothing). Poll briefly
    for a live picker pid before giving up.
    """
    deadline = time.monotonic() + 1.0
    while True:
        old_pid = 0
        try:
            with open(PID_FILE) as f:
                old_pid = int(f.read().strip())
        except Exception:
            old_pid = 0
        if old_pid and old_pid != os.getpid() and pid_is_picker(old_pid):
            try:
                os.kill(old_pid, signal.SIGTERM)
            except OSError:
                pass
            return
        if time.monotonic() >= deadline:
            return
        time.sleep(0.02)


def check_toggle_instance():
    """Toggle: a second press closes the picker that is already open.

    An exclusive flock (held for this whole process lifetime) decides who
    is the window, instead of trusting the pid file alone: two presses
    landing in the same instant both used to see an empty pid file and both
    open a window. The kernel drops the lock however the holder dies, so it
    cannot go stale the way a pid file can.

    The lock fd is kept in a global on purpose — closing it would release
    the lock, so it must outlive this function.
    """
    global _ui_lock_fd
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        _ui_lock_fd = os.open(UI_LOCK, os.O_RDWR | os.O_CREAT, 0o644)
        fcntl.flock(_ui_lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        # Lock is taken: the holder is the visible picker -- close it and
        # leave quietly. Losing the race is a normal, expected outcome.
        if _ui_lock_fd is not None:
            os.close(_ui_lock_fd)
            _ui_lock_fd = None
        signal_open_picker()
        sys.exit(0)

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def acquire_generator_lock():
    """Exclusive, non-blocking lock for one cache-generation pass.

    Returns the lock fd, or None when another pass is already running (a
    cold cache takes minutes, so a few impatient keypresses used to start
    several full rebuilds of the same 180+ wallpapers).
    """
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        fd = os.open(GEN_LOCK, os.O_RDWR | os.O_CREAT, 0o644)
    except OSError:
        return None
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        return None
    return fd


def purge_stale_tmp():
    """Drop .tmp files left behind by a killed pass.

    Safe only while holding the generator lock: live passes write their
    .tmp next to the target, so a leftover can have no living owner.
    """
    try:
        names = os.listdir(CACHE_DIR)
    except OSError:
        return
    for name in names:
        if name.endswith(".tmp"):
            try:
                os.remove(os.path.join(CACHE_DIR, name))
            except OSError:
                pass


def cleanup_pid():
    try:
        with open(PID_FILE) as f:
            if int(f.read().strip()) == os.getpid():
                os.remove(PID_FILE)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# CSS
# ---------------------------------------------------------------------------

def apply_css():
    screen = Gdk.Screen.get_default()
    provider = Gtk.CssProvider()

    import_colors = ""
    if os.path.isfile(COLORS_CSS):
        import_colors = f'@import url("{COLORS_CSS}");'

    css = f"""
    {import_colors}

    window#wallpaper-picker-window {{
        background-color: alpha(@background, 0.92);
        border: 2px solid @outline_variant;
        border-radius: {WINDOW_RADIUS}px;
        padding: 14px 18px;
    }}

    .card-active {{ opacity: 1.0; }}
    .card-inactive {{ opacity: {INACTIVE_OPACITY}; }}
    .card-inactive:hover {{ opacity: 0.85; }}

    .title-label {{
        color: @on_surface;
        font-size: 13px;
        font-weight: bold;
        margin-top: 4px;
        margin-bottom: 2px;
    }}

    .empty-label {{
        color: @error;
        font-size: 15px;
        font-weight: 500;
        margin: 30px 0;
    }}
    """
    try:
        provider.load_from_data(css.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    except Exception as e:
        print(f"Error loading CSS: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Cache generation (run by sway, detached, via --generate-cache)
# ---------------------------------------------------------------------------

def magick_cmd(args):
    """Run one magick invocation; returns True on success."""
    try:
        res = subprocess.run(
            ["magick"] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return res.returncode == 0
    except FileNotFoundError:
        return False


def image_arg(wall_path):
    """Full path, or just the first frame when dealing with a GIF."""
    return f"{wall_path}[0]" if wall_path.lower().endswith(".gif") else wall_path


def generate_thumbnail(wall_path, out_path):
    """200x200 center-crop, rounded-corner mask applied via alpha."""
    tmp = out_path + ".tmp"
    ok = magick_cmd(
        [
            image_arg(wall_path),
            "-resize", f"{THUMB_SIZE}x{THUMB_SIZE}^",
            "-gravity", "center",
            "-extent", f"{THUMB_SIZE}x{THUMB_SIZE}",
            "(", "+clone", "-alpha", "transparent", "-fill", "white",
            "-draw",
            f"roundrectangle 0,0 {THUMB_SIZE - 1},{THUMB_SIZE - 1} {THUMB_RADIUS},{THUMB_RADIUS}",
            "-alpha", "extract", ")",
            "-compose", "CopyOpacity", "-composite",
            f"PNG:{tmp}",
        ]
    )
    if ok:
        os.replace(tmp, out_path)  # atomic: never leave a truncated thumb


def generate_active_thumb(wall_path, primary):
    """200x250 thumbnail with rounded corners AND the matugen primary
    border baked in. Same width as the side thumbs, 50px taller — the
    carousel reads that size jump as animation."""
    out = active_path(wall_path)
    tmp = out + ".tmp"
    ok = magick_cmd(
        [
            image_arg(wall_path),
            "-resize", f"{ACTIVE_W}x{ACTIVE_H}^",
            "-gravity", "center",
            "-extent", f"{ACTIVE_W}x{ACTIVE_H}",
            "(", "+clone", "-alpha", "transparent", "-fill", "white",
            "-draw",
            f"roundrectangle 0,0 {ACTIVE_W - 1},{ACTIVE_H - 1} {THUMB_RADIUS},{THUMB_RADIUS}",
            "-alpha", "extract", ")",
            "-compose", "CopyOpacity", "-composite",
            # compose resets to Over: CopyOpacity is sticky and would throw
            # the border colour away on the composite below
            "-compose", "Over",
            "(", "+clone", "-fill", "none",
            "-stroke", primary, "-strokewidth", "3",
            "-draw",
            f"roundrectangle 1.5,1.5 {ACTIVE_W - 1.5},{ACTIVE_H - 1.5} {THUMB_RADIUS},{THUMB_RADIUS}",
            ")",
            "-composite",
            f"PNG:{tmp}",
        ]
    )
    if ok:
        os.replace(tmp, out)


def extract_primary(wall_path, out_path):
    """Per-image matugen colors file (only the primary hex is needed by the UI)."""
    primary = "#ffffff"
    if shutil.which("matugen"):
        try:
            # Raw path, NOT image_arg(): matugen's loader has no ImageMagick
            # `file.gif[0]` frame syntax and errors on it, falling back to
            # white. It reads the first frame of a GIF on its own.
            res = subprocess.run(
                ["matugen", "image", wall_path, "-j", "hex", "--dry-run"],
                capture_output=True, text=True, timeout=120,
            )
            data = json.loads(res.stdout)
            primary = data["colors"]["primary"]["default"]["color"]
        except Exception:
            primary = "#ffffff"
    with open(out_path, "w") as f:
        f.write(primary + "\n")


def generate_cache(wall_dir):
    """Rebuild every missing/stale thumb + colors + activated variant."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    for wall in list_wallpapers(wall_dir):
        tp, cp, ap = thumb_path(wall), color_path(wall), active_path(wall)

        if is_stale(wall, tp):
            generate_thumbnail(wall, tp)

        primary = "#ffffff"
        if not os.path.isfile(cp) or is_stale(wall, cp):
            extract_primary(wall, cp)
        try:
            with open(cp) as f:
                line = f.readline().strip()
                if line.startswith("#"):
                    primary = line
        except OSError:
            pass

        # Activated variant whenever it or anything it is made of
        # (crop, thumb, color) is missing or outdated.
        if (
            not os.path.isfile(ap)
            or is_stale(wall, ap)
            or is_stale(tp, ap)
            or is_stale(cp, ap)
        ):
            generate_active_thumb(wall, primary)


# ---------------------------------------------------------------------------
# Cache-generator fast path
# ---------------------------------------------------------------------------
# Placed after the cache code (it needs it) and before GTK is imported (it
# needs none of it). pygobject's C extension drags in the whole stdlib asyncio
# module — it accesses asyncio.InvalidStateError at init, so that cost is not
# avoidable — and then libgtk's typelib is parsed: ~0.8s together. The launcher
# starts this pass on every keypress, so the old order charged the user twice
# for one picker window and stole CPU from the import they were waiting on.
if "--generate-cache" in sys.argv[1:]:
    _gen_lock = acquire_generator_lock()
    if _gen_lock is not None:  # None: an earlier pass is still running
        purge_stale_tmp()
        generate_cache(wallpaper_dir())
    sys.exit(0)


# ---------------------------------------------------------------------------
# GTK (imported late: see the fast path above)
# ---------------------------------------------------------------------------

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

class WallpaperCarousel(Gtk.Window):
    def __init__(self, wallpapers):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)

        self.all_wallpapers = wallpapers
        self.filtered_wallpapers = list(wallpapers)
        self.current_idx = 0
        self.pixbuf_cache = {}
        self.search_query = ""
        self._refresh_id = None
        self._retries = 0

        screen = Gdk.Screen.get_default()
        self.visible_count = 7 if (screen and screen.get_width() >= 1900) else 5

        GLib.set_prgname("wallpaper-picker")
        self.set_title("Wallpaper Picker")
        self.set_name("wallpaper-picker-window")
        self.set_decorated(False)

        scr = self.get_screen()
        visual = scr.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(self.main_box)

        # Carousel row
        self.carousel_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=CARD_SPACING
        )
        self.carousel_box.set_halign(Gtk.Align.CENTER)
        self.carousel_box.get_style_context().add_class("carousel-box")
        self.main_box.pack_start(self.carousel_box, True, True, 0)

        # Cleaned-up name of the selected image, e.g. "no-name-1.png" →
        # "No Name 1". No path, no extension, no counter.
        self.title_label = Gtk.Label()
        self.title_label.get_style_context().add_class("title-label")
        self.main_box.pack_start(self.title_label, False, False, 0)

        # Empty state
        self.empty_label = Gtk.Label(label="No matching wallpapers found")
        self.empty_label.get_style_context().add_class("empty-label")
        self.empty_label.set_no_show_all(True)
        self.main_box.pack_start(self.empty_label, False, False, 0)

        # Card slots
        self.card_slots = []
        for i in range(self.visible_count):
            eb = Gtk.EventBox()
            eb.connect("button-press-event", self.on_card_clicked, i)
            img = Gtk.Image()
            eb.add(img)
            self.carousel_box.pack_start(eb, False, False, 0)
            self.card_slots.append((eb, img))

        self.connect("key-press-event", self.on_key_press)
        self.connect("scroll-event", self.on_scroll)
        self.connect("destroy", self.on_destroy)

        GLib.idle_add(self.update_carousel)

    # --- thumbnails ------------------------------------------------------

    def preview_source(self, wall_path, active):
        """Selected card shows the wider bordered thumb; sides the plain one."""
        if active and os.path.isfile(active_path(wall_path)):
            return active_path(wall_path)
        tp = thumb_path(wall_path)
        if os.path.isfile(tp):
            return tp
        return wall_path

    def load_pixbuf(self, source):
        if source in self.pixbuf_cache:  # cached, including failed loads
            return self.pixbuf_cache[source]
        try:
            # Cached thumbs are already at display size, so the scale hint
            # only makes gdk-pixbuf scale a copy of itself (~20% slower per
            # thumbnail, 5-7 of them per redraw). Only the uncached fallback
            # to a full-size wallpaper actually needs scaling.
            info = GdkPixbuf.Pixbuf.get_file_info(source)
            pb = None
            if info and info[1] <= ACTIVE_W and info[2] <= ACTIVE_H:
                pb = GdkPixbuf.Pixbuf.new_from_file(source)
            if pb is None:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    source, ACTIVE_W, ACTIVE_H, True
                )
        except Exception:
            pb = None
        # Cap the cache whether the load succeeded or failed; otherwise a
        # run of unreadable files would grow the failure entries forever.
        self.pixbuf_cache[source] = pb
        while len(self.pixbuf_cache) > 60:
            self.pixbuf_cache.pop(next(iter(self.pixbuf_cache)))
        return pb

    # --- rendering -------------------------------------------------------

    def update_carousel(self):
        count = len(self.filtered_wallpapers)
        if count == 0:
            self.carousel_box.hide()
            self.title_label.hide()
            self.empty_label.show()
            return

        self.empty_label.hide()
        self.carousel_box.show()
        self.title_label.show()

        self.current_idx = max(0, min(count - 1, self.current_idx))
        active_file = self.filtered_wallpapers[self.current_idx]
        filename = os.path.basename(active_file)
        self.title_label.set_text(
            os.path.splitext(filename)[0].replace("-", " ").replace("_", " ").title()
        )

        display_count = min(self.visible_count, count)
        half = display_count // 2

        missing_thumbs = False
        for i, (eb, img) in enumerate(self.card_slots):
            if i >= display_count:
                eb.hide()
                continue
            eb.show()

            offset = i - half
            idx = (self.current_idx + offset + count) % count
            wall_path = self.filtered_wallpapers[idx]
            active = offset == 0

            ctx = eb.get_style_context()
            ctx.remove_class("card-active" if not active else "card-inactive")
            ctx.add_class("card-active" if active else "card-inactive")

            source = self.preview_source(wall_path, active)
            pb = self.load_pixbuf(source)
            if pb:
                img.set_from_pixbuf(pb)
            else:
                img.clear()
                if source == wall_path:
                    # cache thumb not there yet (first run) — re-check later
                    missing_thumbs = True

        if missing_thumbs:
            self._schedule_refresh()
        return False  # always: one-shot, used directly and as an idle callback

    def _schedule_refresh(self):
        if self._refresh_id or self._retries >= CACHE_RETRIES:
            return
        self._refresh_id = GLib.timeout_add(CACHE_RETRY_MS, self._refresh)

    def _refresh(self):
        self._refresh_id = None
        self._retries += 1
        self.update_carousel()
        return False

    # --- input -----------------------------------------------------------

    def on_card_clicked(self, widget, event, slot_index):
        if event.button != 1:
            return False
        count = len(self.filtered_wallpapers)
        if count == 0:
            return False
        display_count = min(self.visible_count, count)
        offset = slot_index - display_count // 2
        if offset == 0:
            self.apply_current()
        else:
            self.current_idx = (self.current_idx + offset + count) % count
            self.update_carousel()
        return True

    def on_key_press(self, widget, event):
        keyval = event.keyval

        if keyval == Gdk.KEY_Escape:
            if self.search_query:
                self.search_query = ""
                self._apply_filter()
            else:
                self.close_and_exit()
            return True

        if keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self.apply_current()
            return True

        if keyval == Gdk.KEY_Left:
            self.step(-1)
            return True

        if keyval == Gdk.KEY_Right:
            self.step(1)
            return True

        # Backspace edits the invisible search query
        if keyval == Gdk.KEY_BackSpace and self.search_query:
            self.search_query = self.search_query[:-1]
            self._apply_filter()
            return True

        # Any printable keystroke feeds the invisible search (fix 2: the
        # search stays enabled, there is just no search UI to show). Ignore
        # keystrokes with Ctrl/Alt/Super held so shortcuts don't type into
        # the query (Alt+letter still yields a printable event.string).
        if event.string and event.string.isprintable():
            mods = event.state & (
                Gdk.ModifierType.CONTROL_MASK
                | Gdk.ModifierType.MOD1_MASK     # Alt
                | Gdk.ModifierType.SUPER_MASK
                | Gdk.ModifierType.META_MASK
            )
            if not mods:
                self.search_query += event.string
                self._apply_filter()
                return True

        return False

    def on_scroll(self, widget, event):
        if event.direction == Gdk.ScrollDirection.SMOOTH:
            delta = event.delta_y
        elif event.direction in (Gdk.ScrollDirection.DOWN, Gdk.ScrollDirection.RIGHT):
            delta = 1
        elif event.direction in (Gdk.ScrollDirection.UP, Gdk.ScrollDirection.LEFT):
            delta = -1
        else:
            return False
        if delta:
            self.step(1 if delta > 0 else -1)
        return True

    def step(self, delta):
        count = len(self.filtered_wallpapers)
        if count:
            self.current_idx = (self.current_idx + delta) % count
            self.update_carousel()

    def _apply_filter(self):
        query = self.search_query.strip().lower()
        if not query:
            self.filtered_wallpapers = list(self.all_wallpapers)
        else:
            # Match the file name only: matching the whole path made common
            # directory names (e.g. "wall") match every wallpaper.
            self.filtered_wallpapers = [
                f for f in self.all_wallpapers
                if query in os.path.basename(f).lower()
            ]
        self.current_idx = 0
        self.update_carousel()

    # --- apply / close ---------------------------------------------------

    def apply_current(self):
        count = len(self.filtered_wallpapers)
        if count == 0:
            return
        selected = self.filtered_wallpapers[self.current_idx]
        if not os.path.isfile(selected):
            return

        # Hand off to sway so apply-wallpaper.sh (awww transition +
        # matugen retheme) keeps running after this process is gone.
        # shlex.quote: a filename with a single quote must neither break the
        # shell string swaymsg hands to `sh -c` nor inject commands.
        command = f"{shlex.quote(APPLY_SCRIPT)} {shlex.quote(selected)}"
        applied = False
        try:
            res = subprocess.run(
                ["swaymsg", "exec", command],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                timeout=5,
            )
            applied = res.returncode == 0
        except (OSError, subprocess.SubprocessError):
            applied = False
        if not applied:
            # No sway IPC (or it rejected the exec): run the applier
            # directly, detached so it outlives the picker.
            subprocess.Popen(
                ["sh", APPLY_SCRIPT, selected],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        self.close_and_exit()

    def close_and_exit(self):
        cleanup_pid()
        self.destroy()
        if Gtk.main_level() > 0:
            Gtk.main_quit()

    def on_destroy(self, widget):
        cleanup_pid()
        if Gtk.main_level() > 0:
            Gtk.main_quit()


# ---------------------------------------------------------------------------

def main():
    # --generate-cache never reaches here: it runs and exits at the top of
    # the module, before GTK is imported.
    check_toggle_instance()
    signal.signal(signal.SIGINT, lambda s, f: (cleanup_pid(), sys.exit(0)))
    signal.signal(signal.SIGTERM, lambda s, f: (cleanup_pid(), sys.exit(0)))

    wallpapers = list_wallpapers(wallpaper_dir(), shuffle=True)
    if not wallpapers:
        subprocess.run(["notify-send", "-a", "Wallpaper Picker", "No wallpapers found"])
        cleanup_pid()
        sys.exit(1)

    apply_css()
    win = WallpaperCarousel(wallpapers)
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
