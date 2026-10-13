import QtQuick
import QtQuick.Layouts

Window {
    width: 800; height: 480
    visible: true
    color: "#111418"
    title: "Mini Dash"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Text {
            id: clock
            Layout.alignment: Qt.AlignHCenter
            color: "#8a93a0"
            font.pixelSize: 50
            text: Qt.formatTime(new Date(), "hh:mm")
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        // Barre de température CPU
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 400; height: 16; radius: 8
            color: "#252a31"

            Rectangle {
                height: parent.height; radius: 8
                width: parent.width * Math.min(backend.cpuTemp / 85, 1)
                color: backend.cpuTemp > 70 ? "#e5484d" : "#3ecf8e"
                Behavior on width { NumberAnimation { duration: 400 } }
                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }
    }
}