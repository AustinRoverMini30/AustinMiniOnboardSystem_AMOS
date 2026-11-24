import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../components"

Item {
    id: dashboardLightAnimation

    property color primaryColor: "#2d5fff"
    property color haloColor: backend.dashboardLightColor
    property int ledBrightness: 80
    property int animationMode: backend.dashboardLightAnimationMode
    property real colorCyclePhase: 0
    property bool previewActive: visible && SwipeView.isCurrentItem
    property var animationOptions: [
        { label: "Gauche → droite", mode: 0 },
        { label: "Centre → extrémités", mode: 1 },
        { label: "Extrémités → centre", mode: 2 }
    ]

    function firstLightPosition(mode, phase) {
        if (mode === 0)
            return phase
        const distanceFromCenter = mode === 1 ? phase / 2 : (1 - phase) / 2
        return 0.5 - distanceFromCenter
    }

    function secondLightPosition(mode, phase) {
        if (mode === 0)
            return phase
        const distanceFromCenter = mode === 1 ? phase / 2 : (1 - phase) / 2
        return 0.5 + distanceFromCenter
    }

    Component.onCompleted: {
        backend.setDashboardLightBrightness(ledBrightness)
        backend.setLedAnimationPreview(previewActive)
    }

    onPreviewActiveChanged: backend.setLedAnimationPreview(previewActive)

    NumberAnimation on colorCyclePhase {
        from: 0
        to: 1
        duration: 5000
        loops: Animation.Infinite
        running: dashboardLightAnimation.previewActive
    }

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
            visible: false
            layer.enabled: true

            color: Qt.rgba(haloColor.r, haloColor.g, haloColor.b, 0.12)
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
            visible: false
            layer.enabled: true

            color: Qt.rgba(haloColor.r, haloColor.g, haloColor.b, 0.2)
        }

        MultiEffect {
            anchors.fill: glowInnerSource
            source: glowInnerSource
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 10 / 32
        }

        Rectangle {
            id: glowSpotLeftSource
            x: lampRectangle.x
               + dashboardLightAnimation.firstLightPosition(
                     dashboardLightAnimation.animationMode,
                     dashboardLightAnimation.colorCyclePhase
                 ) * (lampRectangle.width - width)
            y: lampRectangle.y - 4
            width: lampRectangle.width * 0.12
            height: lampRectangle.height + 26
            radius: height / 2
            color: Qt.rgba(haloColor.r, haloColor.g, haloColor.b, 0.85)
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: glowSpotLeftSource
            source: glowSpotLeftSource
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 18 / 32
        }

        Rectangle {
            id: glowSpotRightSource
            x: lampRectangle.x
               + dashboardLightAnimation.secondLightPosition(
                     dashboardLightAnimation.animationMode,
                     dashboardLightAnimation.colorCyclePhase
                 ) * (lampRectangle.width - width)
            y: lampRectangle.y - 4
            width: lampRectangle.width * 0.12
            height: lampRectangle.height + 26
            radius: height / 2
            color: Qt.rgba(haloColor.r, haloColor.g, haloColor.b, 0.85)
            visible: dashboardLightAnimation.animationMode !== 0
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: glowSpotRightSource
            source: glowSpotRightSource
            visible: dashboardLightAnimation.animationMode !== 0
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 18 / 32
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
        width: animationSelector.implicitWidth + 24
        height: animationSelector.implicitHeight + 20
        radius: 12
        color: "#cc13181e"
        border.width: 1
        border.color: "#59616c"
        z: 3

        Row {
            id: animationSelector
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: dashboardLightAnimation.animationOptions

                delegate: Button {
                    id: animationButton
                    required property var modelData
                    width: 132
                    height: 54
                    padding: 0
                    onClicked: backend.setDashboardLightAnimation(modelData.mode)

                    background: Rectangle {
                        radius: 8
                        color: "#252a31"
                        border.width: dashboardLightAnimation.animationMode === animationButton.modelData.mode ? 2 : 1
                        border.color: dashboardLightAnimation.animationMode === animationButton.modelData.mode
                                      ? dashboardLightAnimation.haloColor : "#59616c"
                    }

                    contentItem: Text {
                        text: animationButton.modelData.label
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                value: dashboardLightAnimation.ledBrightness
                enabled: backend.ledsAvailable
                onMoved: {
                    dashboardLightAnimation.ledBrightness = Math.round(value)
                    backend.setDashboardLightBrightness(dashboardLightAnimation.ledBrightness)
                }
            }
        }
    }
}
