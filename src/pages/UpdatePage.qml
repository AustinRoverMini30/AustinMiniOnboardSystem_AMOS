import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: updatePage
    property color primaryColor: "#2d5fff"

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        width: parent.width * 0.8
        spacing: 18

        EurostileText {
            Layout.alignment: Qt.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 40
            font.weight: Font.DemiBold
            text: "Mise à jour"
        }

        EurostileText {
            Layout.fillWidth: true
            color: "#8a93a0"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            text: "Version installée : " + backend.currentVersion
        }

        EurostileText {
            Layout.fillWidth: true
            color: backend.latestVersion ? updatePage.primaryColor : "#ffffff"
            font.pixelSize: 22
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: backend.updateAvailable
                ? (backend.updateSource === "usb"
                   ? "Version sur USB : " : "Nouvelle version : ")
                  + backend.latestVersion
                : backend.updateStatus
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            visible: backend.updateInProgress

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "#252a31"
            }

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, backend.updateProgress))
                height: parent.height
                radius: 4
                color: updatePage.primaryColor
            }
        }

        EurostileText {
            Layout.fillWidth: true
            color: "#8a93a0"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: backend.updateStatus
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 16

            DashButton {
                primaryColor: updatePage.primaryColor
                text: "Rechercher"
                implicitWidth: 170
                enabled: !backend.updateInProgress
                onClicked: backend.checkForUpdates()
            }

            DashButton {
                primaryColor: updatePage.primaryColor
                text: backend.updateInProgress
                    ? "En cours..."
                    : (backend.updateSource === "usb"
                       ? "Installer USB" : "Télécharger")
                implicitWidth: 190
                primary: true
                fillColor: updatePage.primaryColor
                enabled: backend.updateAvailable && !backend.updateInProgress
                onClicked: backend.startUpdate()
            }
        }
    }
}
