import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: settingsPage
    property color primaryColor: "#2d5fff"
    property var primaryColorOptions: [
        "#2d5fff", "#00b4ff", "#00c853", "#76d600",
        "#ffc400", "#ff7a00", "#ff2d3d", "#ff2d95",
        "#b030ff", "#00a35c"
    ]

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.8
        spacing: 24

        EurostileText {
            Layout.alignment: Qt.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 40
            font.weight: Font.DemiBold
            text: "Paramètres"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 72
            radius: 14
            color: "#13181e"
            border.width: 1
            border.color: "#2c333c"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 16

                EurostileText {
                    Layout.fillWidth: true
                    color: "#ffffff"
                    font.pixelSize: 20
                    text: "Kiosque au démarrage"
                }

                Switch {
                    id: kioskStartupSwitch
                    checked: backend.kioskAtStartup
                    onToggled: backend.setKioskAtStartup(checked)

                    indicator: Rectangle {
                        implicitWidth: 48
                        implicitHeight: 26
                        x: kioskStartupSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: kioskStartupSwitch.checked ? settingsPage.primaryColor : "#3a424d"
                        border.color: kioskStartupSwitch.checked ? settingsPage.primaryColor : "#3d4553"

                        Rectangle {
                            x: kioskStartupSwitch.checked ? parent.width - width : 0
                            width: 26
                            height: 26
                            radius: 13
                            color: kioskStartupSwitch.down ? "#cccccc" : "#ffffff"
                            border.color: kioskStartupSwitch.checked
                                         ? settingsPage.primaryColor : "#999999"
                        }
                    }

                    contentItem: EurostileText {
                        text: kioskStartupSwitch.text
                        font: kioskStartupSwitch.font
                        opacity: enabled ? 1.0 : 0.3
                        color: settingsPage.primaryColor
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: kioskStartupSwitch.indicator.width + kioskStartupSwitch.spacing
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 112
            radius: 14
            color: "#13181e"
            border.width: 1
            border.color: "#2c333c"

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 8

                EurostileText {
                    Layout.fillWidth: true
                    color: "#ffffff"
                    font.pixelSize: 18
                    text: "Couleur principale"
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Repeater {
                        model: settingsPage.primaryColorOptions

                        delegate: Item {
                            id: colorOption
                            required property string modelData
                            width: 42
                            height: 42

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                radius: width / 2
                                color: colorOption.modelData
                                border.width: settingsPage.primaryColor.toString()
                                              === colorOption.modelData ? 3 : 1
                                border.color: settingsPage.primaryColor.toString()
                                              === colorOption.modelData ? "#ffffff" : "#59616c"
                            }

                            TapHandler {
                                onTapped: backend.setPrimaryColor(colorOption.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
