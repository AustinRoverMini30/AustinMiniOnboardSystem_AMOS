import QtQuick

Item {
    id: voltageGauge
    property url gaugeSource
    property url gaugeSource1
    property real value: 0
    property real maximum: 20
    property string unit: "V"
    property real gaugeSize: Math.min(width, height - 20)

    function clampedValue() {
        return Math.max(0, Math.min(value, maximum))
    }

    function needleRotation() {
        var clamped = clampedValue()
        if (clamped <= 10)
            return -40 - clamped / 10 * 5
        if (clamped <= 11)
            return -45 - (clamped - 10) * 6.75
        if (clamped <= 12)
            return -51.75 - (clamped - 11) * 12.8
        if (clamped <= 13)
            return -64.55 - (clamped - 12) * 17.2
        if (clamped <= 15)
            return -81.75 - (clamped - 13) * 11.625
        if (clamped <= 16)
            return -105 - (clamped - 15) * 11.43
        if (clamped <= 17)
            return -116.43 - (clamped - 16) * 11.37
        return -127.8 - (clamped - 17) * (8.2 / 3)
    }

    Image {
        id: gaugeImage1
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: voltageGauge.gaugeSize
        height: width
        source: voltageGauge.gaugeSource1
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        anchors.centerIn: gaugeImage
        anchors.verticalCenterOffset: -gaugeImage.height * 0.20
        width: gaugeImage.width * 0.88
        height: width * 0.17
        source: "../../assets/Aiguille_volt.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        transformOrigin: Item.Center
        rotation: voltageGauge.needleRotation()
        Behavior on rotation {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutQuad
            }
        }
    }

    Image {
        id: gaugeImage
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: voltageGauge.gaugeSize
        height: width
        source: voltageGauge.gaugeSource
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
