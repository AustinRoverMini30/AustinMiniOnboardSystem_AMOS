import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 800; height: 480
    visible: true
    color: "#111418"
    title: "Mini Dash"

    SwipeView {
        id: swipe
        anchors.fill: parent

        // Page 1 : horloge
        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    id: clock
                    Layout.alignment: Qt.AlignHCenter
                    color: "#ffffff"
                    font.pixelSize: 150
                    text: Qt.formatTime(new Date(), "hh:mm")
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }
            }
        }

        // Page 2 : test
        Item {
            Text {
                anchors.centerIn: parent
                color: "#3ecf8e"
                font.pixelSize: 80
                text: "Page 2"
            }
        }
    }

    PageIndicator {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        count: swipe.count
        currentIndex: swipe.currentIndex
    }
}