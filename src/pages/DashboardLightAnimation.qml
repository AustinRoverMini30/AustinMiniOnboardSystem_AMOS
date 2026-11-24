import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../components"

Item {
    id: dashboardLightAnimation

    property color primaryColor: "#2d5fff"
    property int ledBrightness: 80
    property int animationMode: backend.dashboardLightAnimationMode
    property real colorCyclePhase: 0
    property var animationOptions: [
        { label: "Arc-en-ciel", mode: 0 },
        { label: "Dégradé", mode: 1 },
        { label: "Respiration", mode: 2 }
    ]

    function animationColor(mode, position, phase) {
        let hue
        let value = 1.0
        if (mode === 0) {
            hue = (phase + position) % 1
        } else if (mode === 1) {
            hue = (phase * 0.35 + position * 0.55) % 1
        } else {
            hue = (0.08 + position * 0.72) % 1
            value = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(phase * 2 * Math.PI))
        }

        const saturation = 0.9
        const sector = hue * 6
        const chroma = value * saturation
        const secondary = chroma * (1 - Math.abs(sector % 2 - 1))
        const offset = value - chroma
        let red = 0
        let green = 0
        let blue = 0

        if (sector < 1) {
            red = chroma
            green = secondary
        } else if (sector < 2) {
            red = secondary
            green = chroma
        } else if (sector < 3) {
            green = chroma
            blue = secondary
        } else if (sector < 4) {
            green = secondary
            blue = chroma
        } else if (sector < 5) {
            red = secondary
            blue = chroma
        } else {
            red = chroma
            blue = secondary
        }

        return Qt.rgba(red + offset, green + offset, blue + offset, 1)
    }

    Component.onCompleted: {
        backend.setDashboardLightBrightness(ledBrightness)
    }

    NumberAnimation on colorCyclePhase {
        from: 0
        to: 1
        duration: 5000
        loops: Animation.Infinite
        running: dashboardLightAnimation.visible
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

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).r,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).g,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).b, 0.34
                    )
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.5,
                            dashboardLightAnimation.colorCyclePhase
                        ).r,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.5,
                            dashboardLightAnimation.colorCyclePhase
                        ).g,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.5,
                            dashboardLightAnimation.colorCyclePhase
                        ).b, 0.34
                    )
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 1.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).r,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 1.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).g,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 1.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).b, 0.34
                    )
                }
            }
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

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).r,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).g,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).b, 0.58
                    )
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.5,
                            dashboardLightAnimation.colorCyclePhase
                        ).r,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.5,
                            dashboardLightAnimation.colorCyclePhase
                        ).g,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 0.5,
                            dashboardLightAnimation.colorCyclePhase
                        ).b, 0.58
                    )
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 1.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).r,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 1.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).g,
                        dashboardLightAnimation.animationColor(
                            dashboardLightAnimation.animationMode, 1.0,
                            dashboardLightAnimation.colorCyclePhase
                        ).b, 0.58
                    )
                }
            }
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
                        border.width: dashboardLightAnimation.animationMode === animationButton.modelData.mode ? 2 : 1
                        border.color: dashboardLightAnimation.animationMode === animationButton.modelData.mode
                                      ? "#ffffff" : "#59616c"
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: dashboardLightAnimation.animationColor(
                                           animationButton.modelData.mode, 0,
                                           dashboardLightAnimation.colorCyclePhase)
                            }
                            GradientStop {
                                position: 1
                                color: dashboardLightAnimation.animationColor(
                                           animationButton.modelData.mode, 1,
                                           dashboardLightAnimation.colorCyclePhase)
                            }
                        }
                    }

                    contentItem: Text {
                        text: animationButton.modelData.label
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        style: Text.Outline
                        styleColor: "#80000000"
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
