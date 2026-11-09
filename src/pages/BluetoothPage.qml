import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: bluetoothPage
    property color primaryColor: "#2d5fff"
    signal backRequested()

    Rectangle {
        anchors.fill: parent
        color: "#0d1014"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 108
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            DashButton {
                primaryColor: bluetoothPage.primaryColor
                implicitWidth: 112
                implicitHeight: 42
                font.pixelSize: 15
                text: "‹ Paramètres"
                onClicked: bluetoothPage.backRequested()
            }

            EurostileText {
                Layout.fillWidth: true
                color: "#ffffff"
                font.pixelSize: 30
                font.weight: Font.DemiBold
                text: "Bluetooth"
            }

            DashButton {
                primaryColor: bluetoothPage.primaryColor
                implicitWidth: 168
                implicitHeight: 42
                font.pixelSize: 16
                text: backend.bluetoothBusy ? "Recherche..." : "Rechercher"
                enabled: !backend.bluetoothBusy
                primary: true
                fillColor: bluetoothPage.primaryColor
                onClicked: backend.scanBluetoothDevices()
            }
        }

        EurostileText {
            Layout.fillWidth: true
            color: backend.bluetoothStatus.indexOf("impossible") >= 0
                   || backend.bluetoothStatus.indexOf("échoué") >= 0
                   ? "#e5484d" : "#8a93a0"
            font.pixelSize: 15
            elide: Text.ElideRight
            text: backend.bluetoothStatus
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: "#13181e"
            border.width: 1
            border.color: "#2c333c"
            clip: true

            EurostileText {
                anchors.centerIn: parent
                visible: backend.bluetoothDevices.length === 0 && !backend.bluetoothBusy
                color: "#5b6571"
                font.pixelSize: 17
                text: "Les appareils détectés apparaîtront ici"
            }

            BusyIndicator {
                anchors.centerIn: parent
                running: backend.bluetoothBusy && backend.bluetoothDevices.length === 0
                visible: running
            }

            ListView {
                id: bluetoothDeviceList
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 6
                model: backend.bluetoothDevices
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    width: bluetoothDeviceList.width
                    height: 66
                    radius: 10
                    color: "#1b2027"
                    border.width: modelData.connected ? 1 : 0
                    border.color: bluetoothPage.primaryColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            EurostileText {
                                Layout.fillWidth: true
                                color: "#ffffff"
                                font.pixelSize: 17
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                text: modelData.name
                            }
                            EurostileText {
                                Layout.fillWidth: true
                                color: "#8a93a0"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                text: modelData.address
                            }
                        }

                        EurostileText {
                            visible: modelData.connected
                            color: bluetoothPage.primaryColor
                            font.pixelSize: 14
                            text: "Connecté"
                        }

                        DashButton {
                            primaryColor: bluetoothPage.primaryColor
                            implicitWidth: 132
                            implicitHeight: 44
                            font.pixelSize: 15
                            text: modelData.connected ? "Déconnecter" : "Connecter"
                            enabled: !backend.bluetoothBusy
                            onClicked: {
                                if (modelData.connected)
                                    backend.disconnectBluetoothDevice()
                                else
                                    backend.connectBluetoothDevice(modelData.address)
                            }
                        }
                    }
                }
            }
        }
    }
}
