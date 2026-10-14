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
            width: 120
            height: 60
            checkable: true

            contentItem: Image {
                anchors.centerIn: parent
                width: 32
                height: 32
                source: "../assets/fan.png"
                fillMode: Image.PreserveAspectFit
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: fanButton.checked
                }
            }

            background: Rectangle {
                radius: 10
                color: fanButton.checked ? "#3ecf8e" : "#252a31"
            }
        }

        Button {
            id: onOffButton
            width: 120
            height: 60

            icon.source: "../assets/on-off-button.png"
            icon.width: 32
            icon.height: 32
            icon.color: "#ffffff"
            onClicked: powerDialog.open()

            background: Rectangle {
                radius: 10
                color: "#252a31"
            }
        }
    }

    Dialog {
        id: powerDialog
        title: "Alimentation"
        modal: true
        anchors.centerIn: parent
        width: 360
        padding: 24

        contentItem: ColumnLayout {
            spacing: 20

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Button {
                    width: 100
                    height: 60
                    icon.source: "../assets/on-off-button.png"
                    icon.width: 32
                    icon.height: 32
                    icon.color: "#ffffff"
                    onClicked: {
                        powerDialog.close()
                        backend.shutdown()
                    }
                    background: Rectangle {
                        radius: 10
                        color: "#252a31"
                    }
                }
            }
        }
    }
}