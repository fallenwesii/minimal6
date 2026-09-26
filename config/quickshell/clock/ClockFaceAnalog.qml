import QtQuick
import "."

// ClockFaceAnalog — round analog clock face with date using matugen colors

Item {
    id: root
    width: 220
    height: 300
    clip: false

    property var currentTime: new Date()

    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    property string dayName: root.dayNames[root.currentTime.getDay()]
    property string dateStr: root.currentTime.getDate() + " " + root.monthNames[root.currentTime.getMonth()] + " " + root.currentTime.getFullYear()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = new Date()
            root.dayName = root.dayNames[root.currentTime.getDay()]
            root.dateStr = root.currentTime.getDate() + " " + root.monthNames[root.currentTime.getMonth()] + " " + root.currentTime.getFullYear()
        }
    }

    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 0
        spacing: 8

        // Clock face
        Rectangle {
            id: clockFace
            width: 200
            height: 200
            radius: width / 2
            anchors.right: parent.right
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.6)
            border.width: 1
            border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.5)

            // Hour hand
            Rectangle {
                width: parent.width * 0.04
                height: parent.height * 0.28
                color: Theme.onSurface
                anchors.bottom: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                transformOrigin: Item.Bottom
                rotation: (root.currentTime.getHours() % 12) * 30 + root.currentTime.getMinutes() * 0.5 + root.currentTime.getSeconds() * (0.5 / 60)
                radius: width / 2
                Behavior on rotation { RotationAnimation { duration: 1000; direction: RotationAnimation.Clockwise; easing.type: Easing.Linear } }
            }

            // Minute hand
            Rectangle {
                width: parent.width * 0.025
                height: parent.height * 0.38
                color: Theme.onSurfaceVariant
                anchors.bottom: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                transformOrigin: Item.Bottom
                rotation: root.currentTime.getMinutes() * 6 + root.currentTime.getSeconds() * 0.1
                radius: width / 2
                Behavior on rotation { RotationAnimation { duration: 1000; direction: RotationAnimation.Clockwise; easing.type: Easing.Linear } }
            }

            // Second hand
            Rectangle {
                width: parent.width * 0.012
                height: parent.height * 0.44
                color: Theme.primary
                anchors.bottom: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                transformOrigin: Item.Bottom
                rotation: root.currentTime.getSeconds() * 6
                radius: width / 2
                Behavior on rotation { RotationAnimation { duration: 1000; direction: RotationAnimation.Clockwise; easing.type: Easing.Linear } }
            }

            // Center dot
            Rectangle {
                width: parent.width * 0.04
                height: width
                color: Theme.primary
                anchors.centerIn: parent
                radius: width / 2
            }
        }

        // Date text below clock
        Column {
            anchors.right: parent.right
            spacing: 4

            // Day name (e.g., "Friday") - right-aligned, large
            Text {
                id: dayText
                text: root.dayName
                font.family: Theme.fontFamily
                font.pixelSize: 25
                font.bold: true
                color: Theme.onSurface
                anchors.right: parent.right
                horizontalAlignment: Text.AlignRight

                // Subtle outline/shadow inside day text
                Text {
                    text: parent.text
                    font: parent.font
                    color: Qt.rgba(0, 0, 0, 0.3)
                    x: 1
                    y: 1
                    z: -1
                }
            }

            // Full date (e.g., "25 September 2026") - right-aligned
            Text {
                id: dateText
                text: root.dateStr
                font.family: Theme.fontFamily
                font.pixelSize: 21
                font.bold: true
                color: Theme.onSurfaceVariant
                anchors.right: parent.right
                horizontalAlignment: Text.AlignRight

                // Subtle outline/shadow inside date text
                Text {
                    text: parent.text
                    font: parent.font
                    color: Qt.rgba(0, 0, 0, 0.3)
                    x: 1
                    y: 1
                    z: -1
                }
            }
        }
    }
}
