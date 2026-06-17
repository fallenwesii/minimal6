import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: shell

    property int cornerRadius: 14
    property color cornerColor: "#05070a"
    property string backlightDevice: "intel_backlight"

    property string osdIcon: "audio-volume-high-symbolic"
    property string osdLabel: "Volume"
    property real osdValue: Pipewire.defaultAudioSink?.audio.volume ?? 0
    property bool osdMuted: Pipewire.defaultAudioSink?.audio.muted ?? false
    property bool shouldShowOsd: false

    function showOsd(icon, label, value, muted) {
        osdIcon = icon;
        osdLabel = label;
        osdValue = Math.max(0, Math.min(1, value));
        osdMuted = muted ?? false;
        shouldShowOsd = true;
        osdHideTimer.restart();
    }

    function screenHasFullscreen(screen) {
        const monitor = Hyprland.monitorFor(screen);
        return monitor?.activeWorkspace?.hasFullscreen ?? false;
    }

    function numberFromFile(fileView) {
        const value = parseInt(fileView.text().trim());
        return Number.isNaN(value) ? 0 : value;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio || null
        ignoreUnknownSignals: true

        function onVolumesChanged() {
            shell.showOsd(Pipewire.defaultAudioSink?.audio.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic",
                          "Volume",
                          Pipewire.defaultAudioSink?.audio.volume ?? 0,
                          Pipewire.defaultAudioSink?.audio.muted ?? false);
        }

        function onMutedChanged() {
            shell.showOsd(Pipewire.defaultAudioSink?.audio.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic",
                          "Volume",
                          Pipewire.defaultAudioSink?.audio.volume ?? 0,
                          Pipewire.defaultAudioSink?.audio.muted ?? false);
        }
    }

    FileView {
        id: brightness
        path: "/sys/class/backlight/" + shell.backlightDevice + "/actual_brightness"
        preload: true
        watchChanges: true
        printErrors: false

        onFileChanged: {
            reload();
            const max = shell.numberFromFile(maxBrightness);
            if (max > 0)
                shell.showOsd("display-brightness-symbolic", "Brightness", shell.numberFromFile(brightness) / max, false);
        }
    }

    FileView {
        id: maxBrightness
        path: "/sys/class/backlight/" + shell.backlightDevice + "/max_brightness"
        preload: true
        printErrors: false
    }

    Timer {
        id: osdHideTimer
        interval: 1200
        onTriggered: shell.shouldShowOsd = false
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            property var modelData
            property bool hasFullscreen: shell.screenHasFullscreen(modelData)

            PanelWindow {
                id: corners
                screen: screenScope.modelData
                visible: !screenScope.hasFullscreen
                color: "transparent"
                implicitWidth: screen.width
                implicitHeight: screen.height
                mask: Region {}

                anchors {
                    left: true
                    right: true
                    top: true
                    bottom: true
                }

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-rounded-corners"
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                margins.top: 0

                Canvas {
                    id: topLeft
                    width: shell.cornerRadius
                    height: shell.cornerRadius
                    anchors.left: parent.left
                    anchors.top: parent.top
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = shell.cornerColor;
                        ctx.fillRect(0, 0, width, height);
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.beginPath();
                        ctx.arc(width, height, width, 0, Math.PI * 2);
                        ctx.fill();
                    }
                    Connections {
                        target: shell
                        function onCornerColorChanged() { topLeft.requestPaint(); }
                        function onCornerRadiusChanged() { topLeft.requestPaint(); }
                    }
                }

                Canvas {
                    id: topRight
                    width: shell.cornerRadius
                    height: shell.cornerRadius
                    anchors.right: parent.right
                    anchors.top: parent.top
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = shell.cornerColor;
                        ctx.fillRect(0, 0, width, height);
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.beginPath();
                        ctx.arc(0, height, width, 0, Math.PI * 2);
                        ctx.fill();
                    }
                    Connections {
                        target: shell
                        function onCornerColorChanged() { topRight.requestPaint(); }
                        function onCornerRadiusChanged() { topRight.requestPaint(); }
                    }
                }
            }
        }
    }

    LazyLoader {
        active: shell.shouldShowOsd

        PanelWindow {
            id: osd
            anchors.bottom: true
            margins.bottom: Math.round(screen.height / 5)
            exclusiveZone: 0
            implicitWidth: 360
            implicitHeight: 64
            color: "transparent"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#d90b0f14"
                border.color: "#25ffffff"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 18
                    spacing: 14

                    IconImage {
                        implicitSize: 28
                        source: Quickshell.iconPath(shell.osdIcon)
                        opacity: shell.osdMuted ? 0.55 : 1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Text {
                            text: shell.osdMuted ? shell.osdLabel + " muted" : shell.osdLabel
                            color: "#f2f5f8"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: "#2dffffff"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * shell.osdValue
                                radius: parent.radius
                                color: shell.osdMuted ? "#78818c" : "#88c0d0"
                            }
                        }
                    }

                    Text {
                        text: Math.round(shell.osdValue * 100) + "%"
                        color: "#cbd5df"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 42
                    }
                }
            }
        }
    }
}
