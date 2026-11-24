import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../components"

Item {
    id: dashboardLightPage

    property color primaryColor: "#2d5fff"
    property color haloColor: backend.dashboardLightColor
    property int ledBrightness: 80
    property var haloColorOptions: [
        "#2d5fff", "#00b4ff", "#00c853", "#76d600",
        "#ffc400", "#ff7a00", "#ff2d3d", "#ff2d95",
        "#b030ff", "#00a35c"
    ]

    Component.onCompleted: {
        backend.setDashboardLightColor(haloColor.toString())
        backend.setDashboardLightBrightness(ledBrightness)
    }
    onHaloColorChanged: backend.setDashboardLightColor(haloColor.toString())

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

        transform: Translate { x: 150; y: -80 }

        readonly property real haloWidth: Math.min(parent.width, parent.height * 1.5) * 0.50
        readonly property real haloHeight: parent.height * 0.05
        readonly property color glowColor: dashboardLightPage.haloColor

        // Rectangle de référence (invisible), identique à l'original
        Item {
            id: lampRectangle
            anchors.centerIn: parent
            width: halo.haloWidth
            height: halo.haloHeight
        }

        // Halo large et diffus (ancien : blur 24, spread 10, offset 0/10, bas +20)
        Rectangle {
            id: glowOuterSource
            x: lampRectangle.x - 10
            y: lampRectangle.y
            width: lampRectangle.width + 20
            height: lampRectangle.height + 40
            radius: 12
            color: Qt.rgba(halo.glowColor.r, halo.glowColor.g, halo.glowColor.b, 0.34)
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: glowOuterSource
            source: glowOuterSource
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 24 / 32
        }

        // Halo serré et intense (ancien : blur 10, spread 4, offset 0/4, bas +10)
        Rectangle {
            id: glowInnerSource
            x: lampRectangle.x - 4
            y: lampRectangle.y
            width: lampRectangle.width + 8
            height: lampRectangle.height + 18
            radius: 12
            color: Qt.rgba(halo.glowColor.r, halo.glowColor.g, halo.glowColor.b, 0.58)
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: glowInnerSource
            source: glowInnerSource
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 10 / 32
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
                        width: 42
                        height: 42

                        Rectangle {
                            anchors.centerIn: parent
                            width: 42
                            height: 42
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

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: brightnessControl.implicitWidth + 20
        height: brightnessControl.implicitHeight + 24
        radius: 12
        color: "#cc13181e"
        border.width: 1
        border.color: "#59616c"
        z: 3

        Column {
            id: brightnessControl
            anchors.centerIn: parent

            Slider {
                anchors.horizontalCenter: parent.horizontalCenter
                orientation: Qt.Vertical
                height: 240
                from: 0
                to: 255
                stepSize: 1
                value: dashboardLightPage.ledBrightness
                enabled: backend.ledsAvailable
                onMoved: {
                    dashboardLightPage.ledBrightness = Math.round(value)
                    backend.setDashboardLightBrightness(dashboardLightPage.ledBrightness)
                }
            }
        }
    }
}
