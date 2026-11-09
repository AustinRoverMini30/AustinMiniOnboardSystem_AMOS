import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../components"

Item {
    id: startupPage
    property color primaryColor: "#2d5fff"
    signal previewRequested()
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
        anchors.bottomMargin: 20
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            DashButton {
                primaryColor: startupPage.primaryColor
                implicitWidth: 40
                implicitHeight: 40
                font.pixelSize: 15
                text: "‹"
                onClicked: startupPage.backRequested()
            }

            EurostileText {
                Layout.fillWidth: true
                color: "#ffffff"
                font.pixelSize: 30
                font.weight: Font.DemiBold
                text: "Animation de démarrage"
            }
            DashButton {
                primaryColor: startupPage.primaryColor
                implicitWidth: 140
                implicitHeight: 40
                font.pixelSize: 16
                text: "Aperçu"
                onClicked: startupPage.previewRequested()
            }
        }

        GridView {
            id: bootVideoGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 3
            cellHeight: 174
            model: backend.bootVideos
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: videoCard
                required property var modelData
                readonly property bool selected: modelData.file === backend.bootVideoFile

                width: bootVideoGrid.cellWidth - 12
                height: bootVideoGrid.cellHeight - 12
                radius: 10
                color: selected ? startupPage.primaryColor : "#1b2027"
                border.width: selected ? 2 : 1
                border.color: selected ? startupPage.primaryColor : "#2c333c"

                Item {
                    id: thumbnail
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: width * 9 / 16

                    Image {
                        id: thumbnailImage
                        anchors.fill: parent
                        source: videoCard.modelData.thumbnail
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: false
                    }

                    Item {
                        id: thumbnailMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: "white"
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: thumbnailImage
                        maskEnabled: true
                        maskSource: thumbnailMask
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.width: videoCard.selected ? 2 : 1
                    border.color: videoCard.selected ? startupPage.primaryColor : "#2c333c"
                }

                EurostileText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: thumbnail.bottom
                    anchors.topMargin: 3
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    color: "#ffffff"
                    font.pixelSize: 17
                    elide: Text.ElideRight
                    text: videoCard.modelData.name
                }

                EurostileText {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 7
                    visible: videoCard.selected
                    color: startupPage.primaryColor
                    font.pixelSize: 20
                    text: "✓"
                }

                TapHandler {
                    onTapped: backend.setBootVideo(videoCard.modelData.file)
                }
            }
        }
    }
}
