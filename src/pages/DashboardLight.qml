import QtQuick
import QtQuick.Effects

Item {
    id: dashboardLightPage

    property color primaryColor: "#2d5fff"
    property color haloColor: "#ffc400"

    Image {
        anchors.fill: parent
        source: "../../assets/dashboard_front.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Item {
        id: halo
        anchors.fill: parent

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
    }
}
