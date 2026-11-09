import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: updatePage
    property color primaryColor: "#2d5fff"
    signal backRequested()

    Rectangle {
        anchors.fill: parent
        color: "#0d1014"
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.9
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            DashButton {
                primaryColor: updatePage.primaryColor
                implicitWidth: 40
                implicitHeight: 40
                font.pixelSize: 15
                text: "‹"
                onClicked: updatePage.backRequested()
            }

            EurostileText {
                Layout.fillWidth: true
                color: "#ffffff"
                font.pixelSize: 32
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: "Mise à jour"
            }

            Item {
                Layout.preferredWidth: 112
            }
        }

        EurostileText {
            Layout.fillWidth: true
            color: "#8a93a0"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            text: "Version installée : " + backend.currentVersion
        }

        EurostileText {
            Layout.fillWidth: true
            color: backend.latestVersion ? updatePage.primaryColor : "#ffffff"
            font.pixelSize: 20
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
            Layout.topMargin: 4
            spacing: 12

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
