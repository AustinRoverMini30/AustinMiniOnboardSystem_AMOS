import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 24

        EurostileText {
            id: clock
            Layout.alignment: Qt.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 160
            font.weight: Font.Light
            font.letterSpacing: 4
            text: Qt.formatTime(new Date(), "hh:mm")

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }
    }
}
