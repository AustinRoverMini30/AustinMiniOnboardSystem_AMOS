import QtQuick
import "."

Item {
    id: gaugeView
    property url gaugeSource
    property string title: ""
    property string unit: "%"
    property real value: 0
    property real maximum: 100
    property real startAngle: -50
    property real sweep: 250
    property real gaugeSize: Math.min(width, height - 44)

    function clampedValue() {
        return Math.max(0, Math.min(value, maximum))
    }

    function needleRotation() {
        return startAngle + clampedValue() / maximum * sweep
    }

    Image {
        id: gaugeImage
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: gaugeView.gaugeSize
        height: width
        source: gaugeView.gaugeSource
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        anchors.centerIn: gaugeImage
        width: gaugeImage.width * 0.88
        height: width * 0.17
        source: "../../assets/Aiguille.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        transformOrigin: Item.Center
        rotation: gaugeView.needleRotation()
        Behavior on rotation {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutQuad
            }
        }
    }

    EurostileText {
        anchors.top: gaugeImage.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#ffffff"
        font.pixelSize: 17
        font.weight: Font.Medium
        text: gaugeView.title
    }

    EurostileText {
        anchors.top: parent.top
        anchors.right: parent.right
        color: "#8a93a0"
        font.pixelSize: 14
        text: gaugeView.value.toFixed(0) + " " + gaugeView.unit
    }
}
