import QtQuick

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

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height * 1.5) * 0.50
            height: parent.height * 0.10
            color: dashboardLightPage.haloColor
            opacity: 0.42
            transform: Translate { x: 160; y: -60 }

            layer.enabled: true
            layer.smooth: true
        }
    }

    Image {
        anchors.fill: parent
        source: "../../assets/dashboard_back.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
