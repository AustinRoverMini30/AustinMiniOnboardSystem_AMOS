import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../components"

Item {
    id: dashboardLightAnimation

    property color primaryColor: backend.dashboardLightColor
    property color haloColor: backend.dashboardLightColor
    property int ledBrightness: backend.dashboardLightBrightness
    property int animationMode: backend.dashboardLightAnimationMode
    property real colorCyclePhase: 0
    property bool previewActive: visible && SwipeView.isCurrentItem
    readonly property int gaugeFillCycleCount: 14
    readonly property int gaugeFillDurationMs: 6000
    readonly property int edgesToCenterFillDurationMs: 6000
    readonly property real gaugeFillBeamWidth: 1 / gaugeFillCycleCount
    property var animationOptions: [
        { label: "→", mode: 0 },
        { label: "←→", mode: 1 },
        { label: "→←", mode: 2 },
        { label: "Futuriste", mode: 3 },
        { label: "Remplissage", mode: 4 },
        { label: "Ext.-centre +", mode: 5 }
    ]
    readonly property real futuristicProgress: Math.pow(colorCyclePhase, 3)
    readonly property real futuristicFlashOpacity: colorCyclePhase >= 1
                                                    ? 1
                                                    : (Math.sin(2 * Math.PI
                                                        * (colorCyclePhase
                                                           + 8 * colorCyclePhase
                                                           * colorCyclePhase)) > 0 ? 1 : 0)

    function firstLightPosition(mode, phase) {
        if (mode === 0)
            return -0.2 + phase * 1.4
        if (mode === 4)
            return gaugeFillState(phase).sweepProgress
        if (mode === 5) {
            const fillProgress = Math.max(0, (phase - 0.5) * 2)
            return phase < 0.5 ? phase : 0.5 - fillProgress / 2
        }
        const distanceFromCenter = Math.max(
            0,
            mode === 1 ? -0.2 + phase * 1.4 : 1.2 - phase * 1.4
        )
        return 0.5 - distanceFromCenter
    }

    function secondLightPosition(mode, phase) {
        if (mode === 0)
            return -0.2 + phase * 1.4
        if (mode === 5) {
            const fillProgress = Math.max(0, (phase - 0.5) * 2)
            return phase < 0.5 ? 1 - phase : 0.5 + fillProgress / 2
        }
        const distanceFromCenter = Math.max(
            0,
            mode === 1 ? -0.2 + phase * 1.4 : 1.2 - phase * 1.4
        )
        return 0.5 + distanceFromCenter
    }

    function smoothStep(start, end, value) {
        const t = Math.max(0, Math.min(1, (value - start) / (end - start)))
        return t * t * (3 - 2 * t)
    }

    function gaugeFillState(phase) {
        const cycleCount = dashboardLightAnimation.gaugeFillCycleCount
        const totalProgress = Math.max(0, Math.min(1, phase)) * cycleCount
        const completedCycles = Math.min(cycleCount, Math.floor(totalProgress + 1e-9))
        return {
            completedCycles: completedCycles,
            sweepProgress: Math.max(0, totalProgress - completedCycles)
        }
    }

    function lightOpacity(mode, phase) {
        if (mode === 5)
            return phase >= 0.5 ? 1 - smoothStep(0.98, 1, phase) : 1

        if (mode === 0 || mode === 4) {
            const position = firstLightPosition(mode, phase)
            return smoothStep(-0.2, 0, position)
                   * (1 - smoothStep(1, 1.2, position))
        }

        const distanceFromCenter = mode === 1
                                   ? -0.2 + phase * 1.4
                                   : 1.2 - phase * 1.4
        if (mode === 1) {
            return smoothStep(-0.2, 0, distanceFromCenter)
                   * (1 - smoothStep(1, 1.2, distanceFromCenter))
        }
        return smoothStep(1.2, 1, distanceFromCenter)
               * (1 - smoothStep(0, -0.2, distanceFromCenter))
    }

    Component.onCompleted: {
        backend.setDashboardLightPreviewBrightness(ledBrightness)
        backend.setLedAnimationPreview(previewActive)
    }

    onPreviewActiveChanged: backend.setLedAnimationPreview(previewActive)
    onAnimationModeChanged: {
        colorCyclePhase = 0
        const selectedIndex = animationOptions.findIndex(
            option => option.mode === animationMode
        )
        if (selectedIndex >= 0 && animationSelector.currentIndex !== selectedIndex)
            animationSelector.currentIndex = selectedIndex
    }

    function selectAnimationPage(index) {
        if (index >= 0 && index < animationOptions.length) {
            const mode = animationOptions[index].mode
            if (mode !== backend.dashboardLightAnimationMode)
                backend.setDashboardLightAnimation(mode)
        }
    }

    function animationIndexForMode(mode) {
        const index = animationOptions.findIndex(option => option.mode === mode)
        return index >= 0 ? index : 0
    }

    function animationOptionAtOffset(index, offset) {
        const optionIndex = (index + offset + animationOptions.length)
                            % animationOptions.length
        return animationOptions[optionIndex]
    }

    NumberAnimation on colorCyclePhase {
        from: 0
        to: 1
        duration: 5000
        loops: Animation.Infinite
        running: dashboardLightAnimation.previewActive
                 && dashboardLightAnimation.animationMode < 3
    }

    NumberAnimation {
        target: dashboardLightAnimation
        property: "colorCyclePhase"
        from: 0
        to: 1
        duration: dashboardLightAnimation.animationMode === 4
                  ? dashboardLightAnimation.gaugeFillDurationMs
                  : dashboardLightAnimation.animationMode === 5
                    ? dashboardLightAnimation.edgesToCenterFillDurationMs
                    : 5000
        running: dashboardLightAnimation.previewActive
                 && dashboardLightAnimation.animationMode >= 3
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
            id: futuristicFillSource
            x: lampRectangle.x
            y: lampRectangle.y - 4
            width: Math.max(1, lampRectangle.width
                            * dashboardLightAnimation.futuristicProgress)
            height: lampRectangle.height + 26
            radius: height / 2
            color: haloColor
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: futuristicFillSource
            source: futuristicFillSource
            visible: dashboardLightAnimation.animationMode === 3
            opacity: dashboardLightAnimation.futuristicFlashOpacity
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 18 / 32
        }

        Rectangle {
            id: gaugeFillSource
            anchors.right: lampRectangle.right
            y: lampRectangle.y - 4
            width: lampRectangle.width
                   * dashboardLightAnimation.gaugeFillState(
                       dashboardLightAnimation.colorCyclePhase
                   ).completedCycles
                   * dashboardLightAnimation.gaugeFillBeamWidth
            height: lampRectangle.height + 26
            radius: height / 2
            color: haloColor
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: gaugeFillSource
            source: gaugeFillSource
            visible: dashboardLightAnimation.animationMode === 4
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 12 / 32
        }

        Rectangle {
            id: centerFillSource
            anchors.horizontalCenter: lampRectangle.horizontalCenter
            y: lampRectangle.y - 4
            width: lampRectangle.width
                   * Math.max(
                       0,
                       Math.min(1, (dashboardLightAnimation.colorCyclePhase - 0.5) * 2)
                   )
            height: lampRectangle.height + 26
            radius: height / 2
            color: haloColor
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: centerFillSource
            source: centerFillSource
            visible: dashboardLightAnimation.animationMode === 5
                     && dashboardLightAnimation.colorCyclePhase > 0.5
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 12 / 32
        }

        Rectangle {
            id: glowSpotLeftSource
            x: dashboardLightAnimation.animationMode === 4
               || dashboardLightAnimation.animationMode === 5
               ? lampRectangle.x
                 + dashboardLightAnimation.firstLightPosition(
                     dashboardLightAnimation.animationMode,
                     dashboardLightAnimation.colorCyclePhase
                 ) * lampRectangle.width - width / 2
               : lampRectangle.x
                 + dashboardLightAnimation.firstLightPosition(
                     dashboardLightAnimation.animationMode,
                     dashboardLightAnimation.colorCyclePhase
                 ) * (lampRectangle.width - width)
            y: lampRectangle.y - 4
            width: lampRectangle.width
                   * (dashboardLightAnimation.animationMode === 4
                      ? dashboardLightAnimation.gaugeFillBeamWidth
                      : dashboardLightAnimation.animationMode === 5
                        && dashboardLightAnimation.colorCyclePhase >= 0.5
                        ? 0.04 : 0.12)
            height: lampRectangle.height + 26
            radius: height / 2
            color: Qt.rgba(haloColor.r, haloColor.g, haloColor.b, 0.85)
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: glowSpotLeftSource
            source: glowSpotLeftSource
            visible: dashboardLightAnimation.animationMode !== 3
            opacity: dashboardLightAnimation.lightOpacity(
                         dashboardLightAnimation.animationMode,
                         dashboardLightAnimation.colorCyclePhase
                     )
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 100
            blur: 18 / 32
        }

        Rectangle {
            id: glowSpotRightSource
            x: dashboardLightAnimation.animationMode === 5
               ? lampRectangle.x
                 + dashboardLightAnimation.secondLightPosition(
                     dashboardLightAnimation.animationMode,
                     dashboardLightAnimation.colorCyclePhase
                 ) * lampRectangle.width - width / 2
               : lampRectangle.x
                 + dashboardLightAnimation.secondLightPosition(
                     dashboardLightAnimation.animationMode,
                     dashboardLightAnimation.colorCyclePhase
                 ) * (lampRectangle.width - width)
            y: lampRectangle.y - 4
            width: lampRectangle.width
                   * (dashboardLightAnimation.animationMode === 5
                      && dashboardLightAnimation.colorCyclePhase >= 0.5
                      ? 0.04 : 0.12)
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
                     && dashboardLightAnimation.animationMode !== 3
                     && dashboardLightAnimation.animationMode !== 4
            opacity: dashboardLightAnimation.lightOpacity(
                         dashboardLightAnimation.animationMode,
                         dashboardLightAnimation.colorCyclePhase
                     )
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
        width: animationSelector.width + 20
        height: animationSelector.height + 16
        radius: 12
        color: "#cc13181e"
        border.width: 1
        border.color: "#59616c"
        z: 3

        SwipeView {
            id: animationSelector
            anchors.centerIn: parent
            width: 220
            height: 64
            clip: true
            currentIndex: dashboardLightAnimation.animationIndexForMode(
                              dashboardLightAnimation.animationMode
                          )
            onCurrentIndexChanged: dashboardLightAnimation.selectAnimationPage(
                                       currentIndex
                                   )

            Repeater {
                model: dashboardLightAnimation.animationOptions

                delegate: Item {
                    id: animationButton
                    required property var modelData
                    required property int index
                    width: animationSelector.width
                    height: animationSelector.height

                    Rectangle {
                        id: animationCard
                        x: (animationSelector.width - width) / 2
                        y: 5
                        width: animationSelector.width - 20
                        height: animationSelector.height - 10
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#46515e" }
                            GradientStop { position: 1; color: "#171b20" }
                        }
                        border.width: 2
                        border.color: dashboardLightAnimation.haloColor

                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            text: animationButton.modelData.label
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            height: 2
                            radius: 1
                            color: dashboardLightAnimation.haloColor
                            opacity: 0.7
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
                id: brightnessSlider
                width: 64
                anchors.horizontalCenter: parent.horizontalCenter
                orientation: Qt.Vertical
                height: 320
                from: 0
                to: 255
                stepSize: 1
                value: dashboardLightAnimation.ledBrightness
                enabled: backend.ledsAvailable
                background: Rectangle {
                    x: brightnessSlider.leftPadding
                       + (brightnessSlider.availableWidth - width) / 2
                    y: brightnessSlider.topPadding
                    width: 3
                    height: brightnessSlider.availableHeight
                    radius: width / 2
                    color: "#3a424d"
                }
                handle: Rectangle {
                    x: brightnessSlider.leftPadding
                       + (brightnessSlider.availableWidth - width) / 2
                    y: brightnessSlider.topPadding
                       + brightnessSlider.visualPosition
                       * (brightnessSlider.availableHeight - height)
                    width: 40
                    height: 28
                    radius: 8
                    color: brightnessSlider.pressed ? "#ffffff" : dashboardLightAnimation.haloColor
                    border.width: 1
                    border.color: "#ffffff"
                }
                onMoved: {
                    dashboardLightAnimation.ledBrightness = Math.round(value)
                    backend.setDashboardLightPreviewBrightness(
                        dashboardLightAnimation.ledBrightness
                    )
                }
            }
        }
    }
}
