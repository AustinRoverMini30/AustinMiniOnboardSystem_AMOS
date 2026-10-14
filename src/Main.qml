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

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 24

        Button {
            id: fanButton
            width: 64
            height: 64
            checkable: true

            icon.source: "../assets/fan.png"
            icon.width: 32
            icon.height: 32
            icon.color: checked ? "#111418" : "#ffffff"

            background: Rectangle {
                radius: width / 2
                color: fanButton.checked ? "#3ecf8e" : "#252a31"
            }
        }

        Button {
            id: onOffButton
            width: 64
            height: 64
            checkable: true

            icon.source: "../assets/on-off-button.png"
            icon.width: 32
            icon.height: 32
            icon.color: checked ? "#111418" : "#ffffff"

            background: Rectangle {
                radius: width / 2
                color: onOffButton.checked ? "#3ecf8e" : "#252a31"
            }
        }
    }
}