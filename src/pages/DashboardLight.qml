import QtQuick
import QtQuick.Effects
import "../components"

Item {
    id: dashboardLightPage

    property color primaryColor: "#2d5fff"
    property color haloColor: "#ffc400"
    property var haloColorOptions: [
        "#2d5fff", "#00b4ff", "#00c853", "#76d600",
        "#ffc400", "#ff7a00", "#ff2d3d", "#ff2d95",
        "#b030ff", "#00a35c"
    ]

    Image {
        anchors.fill: parent
        source: "../../assets/dashboard_front.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        z: 0
    }

    Item {
        id: halo
        anchors.fill: parent
        z: 1

        transform: Translate { x: 155; y: -80 }

        readonly property real haloWidth: Math.min(parent.width, parent.height * 1.5) * 0.50
        readonly property real haloHeight: parent.height * 0.05

        Rectangle {
            id: lampRectangle
            anchors.centerIn: parent
            width: halo.haloWidth
            height: halo.haloHeight
            radius: 12
            color: "transparent"
        }

        RectangularShadow {
            anchors.fill: lampRectangle
            anchors.bottomMargin: -20
            color: Qt.rgba(dashboardLightPage.haloColor.r,
                           dashboardLightPage.haloColor.g,
                           dashboardLightPage.haloColor.b, 0.34)
            blur: 24
            spread: 10
            offset: Qt.point(0, 10)
            radius: lampRectangle.radius
        }

        RectangularShadow {
            anchors.fill: lampRectangle
            anchors.bottomMargin: -10
            color: Qt.rgba(dashboardLightPage.haloColor.r,
                           dashboardLightPage.haloColor.g,
                           dashboardLightPage.haloColor.b, 0.58)
            blur: 10
            spread: 4
            offset: Qt.point(0, 4)
            radius: lampRectangle.radius
        }
    }

    Image {
        anchors.fill: parent
        source: "../../assets/dashboard_back.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        z: 2
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: colorSelector.implicitWidth + 24
        height: colorSelector.implicitHeight + 20
        radius: 12
        color: "#cc13181e"
        border.width: 1
        border.color: "#59616c"
        z: 3

        Column {
            id: colorSelector
            anchors.centerIn: parent
            spacing: 7

            EurostileText {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#ffffff"
                font.pixelSize: 14
                text: "Couleur du halo"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 7

                Repeater {
                    model: dashboardLightPage.haloColorOptions

                    delegate: Item {
                        id: colorOption
                        required property string modelData
                        width: 30
                        height: 30

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: width / 2
                            color: colorOption.modelData
                            border.width: dashboardLightPage.haloColor.toString()
                                          === colorOption.modelData ? 3 : 1
                            border.color: dashboardLightPage.haloColor.toString()
                                          === colorOption.modelData ? "#ffffff" : "#59616c"
                        }

                        TapHandler {
                            onTapped: dashboardLightPage.haloColor = colorOption.modelData
                        }
                    }
                }
            }
        }
    }
}
