#!/usr/bin/env python3
"""
Live Wallpaper Switcher — GTK3 horizontal carousel wallpaper picker for SwayFX.
Tailored for animated GIF wallpapers with high-quality frame extraction for Matugen theming.

Flow:
  1. Checks for GIFs inside ~/Pictures/wallpapers/gif/
  2. For each GIF, checks if an MP4 source exists to extract a crisp, high-quality
     vibrant frame (falling back to the GIF itself if no MP4 exists).
  3. Uses the extracted frame for:
       - 200x200 rounded center-cropped thumbnail
       - Matugen primary accent color border
       - 200x250 active selected card
  4. When selected, executes apply-live-wallpaper.sh which:
       - Displays the animated GIF using awww
       - Applies system colors using matugen on the extracted static frame
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

WALLPAPER_DIR = os.path.expanduser("~/Pictures/wallpapers/gif")
SOURCE_SEARCH_DIRS = (
    os.path.expanduser("~/Pictures/wallpapers/gif"),
    os.path.expanduser("~/Downloads/gif"),
)

CACHE_DIR = os.path.expanduser("~/.cache/live-wallpaper-picker")
PID_FILE = os.path.join(CACHE_DIR, "live-wallpaper-picker.pid")
GEN_LOCK = os.path.join(CACHE_DIR, ".generate.lock")
UI_LOCK = os.path.join(CACHE_DIR, ".ui.lock")
_ui_lock_fd = None

APPLY_SCRIPT = os.path.expanduser("~/.config/sway/scripts/apply-live-wallpaper.sh")
COLORS_CSS = os.path.expanduser("~/.config/wofi/colors.css")

SUPPORTED_EXTS = (".gif",)

# --- UI knobs -----------------------------------------------------------
WINDOW_RADIUS = 30
THUMB_RADIUS = 15
THUMB_SIZE = 200
ACTIVE_W = 200
ACTIVE_H = 250
CARD_SPACING = 14
INACTIVE_OPACITY = 0.55
CACHE_RETRY_MS = 2000
CACHE_RETRIES = 8


# ---------------------------------------------------------------------------
# Paths / wallpaper listing
# ---------------------------------------------------------------------------

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


def find_source_video(gif_path):
    """Prefers an MP4 of the same base name for higher quality frame extraction."""
    stem = os.path.splitext(os.path.basename(gif_path))[0]
    for d in SOURCE_SEARCH_DIRS:
        cand = os.path.join(d, stem + ".mp4")
        if os.path.isfile(cand):
            return cand
    return gif_path


def frame_path(wall_path):
    stem = os.path.splitext(os.path.basename(wall_path))[0]
    return os.path.join(CACHE_DIR, stem + ".frame.png")


def thumb_path(wall_path):
    stem = os.path.splitext(os.path.basename(wall_path))[0]
    return os.path.join(CACHE_DIR, stem + ".png")


def active_path(wall_path):
    stem = os.path.splitext(os.path.basename(wall_path))[0]
    return os.path.join(CACHE_DIR, stem + ".active.png")


def color_path(wall_path):
    stem = os.path.splitext(os.path.basename(wall_path))[0]
    return os.path.join(CACHE_DIR, stem + ".colors")


def is_stale(source, cache):
    try:
        return os.path.getmtime(source) > os.path.getmtime(cache)
    except OSError:
        return True


# ---------------------------------------------------------------------------
# Single-instance / toggle behavior
# ---------------------------------------------------------------------------

def pid_is_picker(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read().decode("utf-8", errors="ignore")
    except OSError:
        return False
    return "live-wallpaper-switcher.py" in cmdline and "--generate-cache" not in cmdline


def signal_open_picker():
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
    global _ui_lock_fd
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        _ui_lock_fd = os.open(UI_LOCK, os.O_RDWR | os.O_CREAT, 0o644)
        fcntl.flock(_ui_lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        if _ui_lock_fd is not None:
            os.close(_ui_lock_fd)
            _ui_lock_fd = None
        signal_open_picker()
        sys.exit(0)

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def acquire_generator_lock():
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
    try:
        names = os.listdir(CACHE_DIR)
    except OSError:
        return
    for name in names:
        if ".tmp" in name:
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
# Cache generation
# ---------------------------------------------------------------------------

def magick_cmd(args):
    try:
        res = subprocess.run(
            ["magick"] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return res.returncode == 0
    except FileNotFoundError:
        return False


def extract_best_frame(source_file, out_frame):
    """Extracts the most vibrant, color-rich frame using ffmpeg signalstats."""
    tmp = out_frame + ".tmp.png"
    best_t = "1.0"
    max_score = -1.0

    # Fast scan candidates at 2 fps on a low-res preview stream
    cmd = [
        "ffmpeg", "-v", "error", "-i", source_file,
        "-vf", "fps=2,scale=320:-1:flags=fast_bilinear,signalstats,metadata=print:file=-",
        "-f", "null", "-"
    ]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        curr_t = "0"
        y = 0.0
        sat = 0.0
        sathigh = 0.0
        for line in proc.stdout:
            if "pts_time:" in line:
                parts = line.strip().split("pts_time:")
                if len(parts) > 1:
                    curr_t = parts[1].strip().split()[0]
            elif "lavfi.signalstats.YAVG=" in line:
                try:
                    y = float(line.strip().split("=")[1])
                except ValueError:
                    pass
            elif "lavfi.signalstats.SATAVG=" in line:
                try:
                    sat = float(line.strip().split("=")[1])
                except ValueError:
                    pass
            elif "lavfi.signalstats.SATHIGH=" in line:
                try:
                    sathigh = float(line.strip().split("=")[1])
                except ValueError:
                    pass
                if 20.0 <= y <= 235.0:
                    score = (sat * 1.5) + sathigh
                    if score > max_score:
                        max_score = score
                        best_t = curr_t
        proc.wait()
    except Exception:
        best_t = "1.0"

    # Extract single frame losslessly at native resolution
    subprocess.run(
        [
            "ffmpeg", "-v", "error",
            "-ss", str(best_t),
            "-i", source_file,
            "-frames:v", "1",
            "-f", "image2",
            "-update", "1",
            "-y", tmp
        ],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    if os.path.isfile(tmp):
        os.replace(tmp, out_frame)



def generate_thumbnail(img_path, out_path):
    tmp = out_path + ".tmp"
    ok = magick_cmd(
        [
            img_path,
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
        os.replace(tmp, out_path)


def generate_active_thumb(img_path, out_path, primary):
    tmp = out_path + ".tmp"
    ok = magick_cmd(
        [
            img_path,
            "-resize", f"{ACTIVE_W}x{ACTIVE_H}^",
            "-gravity", "center",
            "-extent", f"{ACTIVE_W}x{ACTIVE_H}",
            "(", "+clone", "-alpha", "transparent", "-fill", "white",
            "-draw",
            f"roundrectangle 0,0 {ACTIVE_W - 1},{ACTIVE_H - 1} {THUMB_RADIUS},{THUMB_RADIUS}",
            "-alpha", "extract", ")",
            "-compose", "CopyOpacity", "-composite",
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
        os.replace(tmp, out_path)


def extract_primary(img_path, out_path):
    primary = "#ffffff"
    if shutil.which("matugen"):
        try:
            res = subprocess.run(
                ["matugen", "image", img_path, "-j", "hex", "--dry-run"],
                capture_output=True, text=True, timeout=120,
            )
            data = json.loads(res.stdout)
            primary = data["colors"]["primary"]["default"]["color"]
        except Exception:
            primary = "#ffffff"
    with open(out_path, "w") as f:
        f.write(primary + "\n")


def generate_cache(wall_dir):
    os.makedirs(CACHE_DIR, exist_ok=True)
    for wall in list_wallpapers(wall_dir):
        fp = frame_path(wall)
        tp = thumb_path(wall)
        cp = color_path(wall)
        ap = active_path(wall)

        # 1. Ensure high-quality static frame exists
        source = find_source_video(wall)
        if not os.path.isfile(fp) or is_stale(source, fp):
            extract_best_frame(source, fp)

        # Fallback if extraction failed
        img_source = fp if os.path.isfile(fp) else wall

        # 2. Thumbnail
        if is_stale(img_source, tp):
            generate_thumbnail(img_source, tp)

        # 3. Matugen Primary Color
        primary = "#ffffff"
        if not os.path.isfile(cp) or is_stale(img_source, cp):
            extract_primary(img_source, cp)
        try:
            with open(cp) as f:
                line = f.readline().strip()
                if line.startswith("#"):
                    primary = line
        except OSError:
            pass

        # 4. Activated Thumbnail with Border
        if (
            not os.path.isfile(ap)
            or is_stale(img_source, ap)
            or is_stale(tp, ap)
            or is_stale(cp, ap)
        ):
            generate_active_thumb(img_source, ap, primary)



# ---------------------------------------------------------------------------
# Fast path for background cache generator
# ---------------------------------------------------------------------------
if "--generate-cache" in sys.argv[1:]:
    _gen_lock = acquire_generator_lock()
    if _gen_lock is not None:
        purge_stale_tmp()
        generate_cache(WALLPAPER_DIR)
    sys.exit(0)


# ---------------------------------------------------------------------------
# GTK imports (only when launching UI)
# ---------------------------------------------------------------------------
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib


# ---------------------------------------------------------------------------
# Carousel UI
# ---------------------------------------------------------------------------

class LiveWallpaperCarousel(Gtk.Window):
    def __init__(self, wallpapers):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)

        self.all_wallpapers = wallpapers
        self.filtered_wallpapers = list(wallpapers)
        self.current_idx = 0
        self.pixbuf_cache = {}
        self.search_query = ""

        screen = Gdk.Screen.get_default()
        self.visible_count = 7 if (screen and screen.get_width() >= 1900) else 5
        self.card_slots = []
        self._refresh_id = None
        self._retries = 0


        self.set_title("Live Wallpaper Switcher")
        GLib.set_prgname("live-wallpaper-picker")
        self.set_wmclass("live-wallpaper-picker", "live-wallpaper-picker")
        self.set_name("wallpaper-picker-window")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.CENTER)

        scr = self.get_screen()
        visual = scr.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.add(root)

        # Carousel row (thumbnails)
        self.carousel_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=CARD_SPACING
        )
        self.carousel_box.set_halign(Gtk.Align.CENTER)
        self.carousel_box.set_valign(Gtk.Align.CENTER)
        root.pack_start(self.carousel_box, True, True, 4)

        for i in range(self.visible_count):
            eb = Gtk.EventBox()
            eb.set_visible_window(False)
            eb.connect("button-press-event", self.on_card_clicked, i)
            img = Gtk.Image()
            eb.add(img)
            self.card_slots.append((eb, img))
            self.carousel_box.pack_start(eb, False, False, 0)

        # Title label below the active bordered thumbnail
        self.title_label = Gtk.Label()
        self.title_label.set_name("title-label")
        self.title_label.get_style_context().add_class("title-label")
        root.pack_start(self.title_label, False, False, 0)


        self.empty_label = Gtk.Label(label="No live wallpapers match your search")
        self.empty_label.get_style_context().add_class("empty-label")
        root.pack_start(self.empty_label, True, True, 0)

        self.connect("key-press-event", self.on_key_press)
        self.connect("scroll-event", self.on_scroll)
        self.connect("destroy", self.on_destroy)

        GLib.idle_add(self.update_carousel)

    def preview_source(self, wall_path, active):
        if active and os.path.isfile(active_path(wall_path)):
            return active_path(wall_path)
        tp = thumb_path(wall_path)
        if os.path.isfile(tp):
            return tp
        fp = frame_path(wall_path)
        if os.path.isfile(fp):
            return fp
        return wall_path

    def load_pixbuf(self, source):
        if source in self.pixbuf_cache:
            return self.pixbuf_cache[source]
        try:
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

        self.pixbuf_cache[source] = pb
        while len(self.pixbuf_cache) > 60:
            self.pixbuf_cache.pop(next(iter(self.pixbuf_cache)))
        return pb

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
                    missing_thumbs = True

        if missing_thumbs:
            self._schedule_refresh()
        return False

    def _schedule_refresh(self):
        if self._refresh_id or self._retries >= CACHE_RETRIES:
            return
        self._refresh_id = GLib.timeout_add(CACHE_RETRY_MS, self._refresh)

    def _refresh(self):
        self._refresh_id = None
        self._retries += 1
        self.update_carousel()
        return False

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

        if keyval == Gdk.KEY_BackSpace and self.search_query:
            self.search_query = self.search_query[:-1]
            self._apply_filter()
            return True

        if event.string and event.string.isprintable():
            mods = event.state & (
                Gdk.ModifierType.CONTROL_MASK
                | Gdk.ModifierType.MOD1_MASK
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
            self.filtered_wallpapers = [
                f for f in self.all_wallpapers
                if query in os.path.basename(f).lower()
            ]
        self.current_idx = 0
        self.update_carousel()

    def apply_current(self):
        count = len(self.filtered_wallpapers)
        if count == 0:
            return
        selected = self.filtered_wallpapers[self.current_idx]
        if not os.path.isfile(selected):
            return

        fp = frame_path(selected)
        command = f"{shlex.quote(APPLY_SCRIPT)} {shlex.quote(selected)} {shlex.quote(fp)}"
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
            subprocess.Popen(
                ["sh", APPLY_SCRIPT, selected, fp],
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
    check_toggle_instance()
    signal.signal(signal.SIGINT, lambda s, f: (cleanup_pid(), sys.exit(0)))
    signal.signal(signal.SIGTERM, lambda s, f: (cleanup_pid(), sys.exit(0)))

    wallpapers = list_wallpapers(WALLPAPER_DIR, shuffle=True)
    if not wallpapers:
        subprocess.run(
            ["notify-send", "-a", "Live Wallpaper Picker", f"No GIFs found in {WALLPAPER_DIR}"]
        )
        cleanup_pid()
        sys.exit(1)

    apply_css()
    win = LiveWallpaperCarousel(wallpapers)
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
