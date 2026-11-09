import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "pages"

ApplicationWindow {
    id: root
    width: 800
    height: 480
    visible: true
    color: "#0d1014"
    title: "AMOS"

    font.family: DashboardFont.family

    property color primaryColor: backend.primaryColor
    property bool showBluetoothPage: false
    property bool showUpdatePage: false

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#171c23" }
            GradientStop { position: 1.0; color: "#0d1014" }
        }
    }

    SwipeView {
        id: swipe
        anchors.fill: parent

        ClockPage {}
        SystemPage { primaryColor: root.primaryColor }
        VoltagePage {}
        JournalPage { primaryColor: root.primaryColor }
        MediaPage { primaryColor: root.primaryColor }
        StartupPage {
            id: startupPage
            primaryColor: root.primaryColor
            onPreviewRequested: splash.start()
        }
        SettingsPage {
            primaryColor: root.primaryColor
            onBluetoothRequested: root.showBluetoothPage = true
            onUpdateRequested: root.showUpdatePage = true
        }
    }

    BluetoothPage {
        anchors.fill: parent
        z: 1
        visible: root.showBluetoothPage
        primaryColor: root.primaryColor
        onBackRequested: root.showBluetoothPage = false
    }

    UpdatePage {
        anchors.fill: parent
        z: 1
        visible: root.showUpdatePage
        primaryColor: root.primaryColor
        onBackRequested: root.showUpdatePage = false
    }

    PageIndicator {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 94
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.showBluetoothPage && !root.showUpdatePage
        count: swipe.count
        currentIndex: swipe.currentIndex

        delegate: Rectangle {
            required property int index
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: index === swipe.currentIndex ? root.primaryColor : "#3a424d"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 20
        visible: !root.showBluetoothPage && !root.showUpdatePage

        DashButton {
            id: fanButton
            primaryColor: root.primaryColor
            checkable: true
            onToggled: backend.setFan(checked)

            contentItem: Item {
                Image {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    source: "../assets/fan.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: fanButton.checked
                    }
                }
            }
        }

        DashButton {
            primaryColor: root.primaryColor
            icon.source: "../assets/on-off-button.png"
            onClicked: powerDialog.open()
        }

        DashButton {
            id: kioskButton
            primaryColor: root.primaryColor
            text: "Kiosque"
            enabled: !kioskOverlay.visible
            onClicked: kioskOverlay.start()
        }
    }

    Dialog {
        id: powerDialog
        parent: Overlay.overlay
        title: "Alimentation"
        modal: true
        anchors.centerIn: parent
        width: 360
        padding: 24

        Overlay.modal: Rectangle { color: "#b0000000" }

        background: Rectangle {
            radius: 20
            color: "#1b2027"
            border.width: 1
            border.color: "#2c333c"
        }

        header: EurostileText {
            topPadding: 24
            color: "#ffffff"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            text: powerDialog.title
        }

        contentItem: ColumnLayout {
            spacing: 20

            EurostileText {
                Layout.fillWidth: true
                color: "#8a93a0"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                text: "Que souhaitez-vous faire ?"
            }

            DashButton {
                primaryColor: root.primaryColor
                Layout.fillWidth: true
                text: "Éteindre"
                icon.source: "../assets/on-off-button.png"
                primary: true
                fillColor: "#e5484d"
                palette.buttonText: "#ffffff"
                icon.color: "#ffffff"
                onClicked: {
                    powerDialog.close()
                    backend.shutdown()
                }
            }

            DashButton {
                primaryColor: root.primaryColor
                Layout.fillWidth: true
                text: "Redémarrer"
                onClicked: {
                    powerDialog.close()
                    backend.restart()
                }
            }
        }
    }

    VideoOverlay {
        id: kioskOverlay
        anchors.fill: parent
        z: 100
        holdLastFrame: true
        fadeDuration: 500
    }

    VideoOverlay {
        id: splash
        anchors.fill: parent
        z: 90
        timeout: 8000
        Component.onCompleted: {
            if (backend.kioskAtStartup)
                kioskOverlay.start()
            else
                start()
        }
    }
}
