pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

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

    function md3(name, fallback) {
        return matugenColors?.md3?.[name] ?? fallback;
    }

    // Use matugen md3 colors directly - no Catppuccin derivation
    property color background: md3("background", "#1e1e2e")
    property color surface: md3("surface", "#2f313e")
    property color surfaceContainer: md3("surface_container", "#3a3c48")
    property color surfaceContainerHigh: md3("surface_container_high", "#45464f")
    property color onSurface: md3("on_surface", "#e6e4ec")
    property color onSurfaceVariant: md3("on_surface_variant", "#cdccd7")
    property color primary: md3("primary", "#bcc9ff")
    property color secondary: md3("secondary", "#c8cbe4")
    property color tertiary: md3("tertiary", "#e9bfe0")
    property color error: md3("error", "#ffbab1")
    property color outline: md3("outline", "#9e9ea9")
    property color outlineVariant: md3("outline_variant", "#5d5e6a")

    property string fontFamily: "Hack Nerd Font"
    property int borderRadius: 10
    property int clampedBorderRadius: 10

    FileView {
        id: matugenColorsFile
        path: root.matugenColorsPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.loadMatugenColors()
        Component.onCompleted: root.loadMatugenColors()
    }
}
