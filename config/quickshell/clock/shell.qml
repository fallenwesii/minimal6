//@ pragma IconTheme Papirus-Dark

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    property string matugenColorsPath: Quickshell.env("HOME") + "/.config/quickshell/generated/colors.json"
    property var matugenColors: ({})

    function loadMatugenColors() {
        try {
            const raw = matugenColorsFile.text().trim();
            if (raw.length > 0)
                matugenColors = JSON.parse(raw);
        } catch (error) {
            console.warn("Failed to load matugen colors:", error);
        }
    }

    function md3Color(name, fallback) {
        return matugenColors?.md3?.[name] ?? fallback;
    }

    function base16Color(name, fallback) {
        return matugenColors?.base16?.[name] ?? fallback;
    }

    // Derive Catppuccin-style colors from matugen base16
    property color base: base16Color("base00", "#1e1e2e")
    property color mantle: base16Color("base01", "#181825")
    property color crust: base16Color("base02", "#11111b")
    property color text: base16Color("base05", "#cdd6f4")
    property color subtext0: base16Color("base04", "#a6adc8")
    property color subtext1: base16Color("base03", "#bac2de")
    property color surface0: base16Color("base01", "#313244")
    property color surface1: base16Color("base02", "#45475a")
    property color surface2: base16Color("base03", "#585b70")
    property color overlay0: base16Color("base04", "#6c7086")
    property color overlay1: base16Color("base03", "#7f849c")
    property color overlay2: base16Color("base02", "#9399b2")
    property color blue: md3Color("primary", "#89b4fa")
    property color sapphire: md3Color("primary", "#74c7ec")
    property color peach: md3Color("tertiary", "#fab387")
    property color green: md3Color("secondary", "#a6e3a1")
    property color red: md3Color("error", "#f38ba8")
    property color mauve: base16Color("base0b", "#cba6f7")
    property color pink: md3Color("tertiary", "#f5c2e7")
    property color yellow: md3Color("primary", "#f9e2af")
    property color maroon: md3Color("error", "#eba0ac")
    property color teal: md3Color("secondary", "#94e2d5")

    FileView {
        id: matugenColorsFile
        path: shell.matugenColorsPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: shell.loadMatugenColors()
        Component.onCompleted: shell.loadMatugenColors()
    }

    // Clock widget at top-right, Background layer (above wallpaper, below apps)
    PanelWindow {
        id: clockWindow
        screen: Quickshell.screens[0]

        // Background layer: above wallpaper, below normal windows
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-clock-analog"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: 0

        // Position at top-right - moved down more so full clock is visible
        anchors.top: true
        anchors.right: true
        margins.top: 80
        margins.right: 32

        // Size - taller to fit clock (200) + spacing (8) + date texts (~70)
        implicitWidth: 220
        implicitHeight: 300

        // Transparent background - no white, no borders
        color: "transparent"

        // The clock face
        Loader {
            anchors.fill: parent
            source: "ClockFaceAnalog.qml"
        }
    }
}
