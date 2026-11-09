import QtQuick
import "../components"

Item {
    id: voltagePage
    property real voltage: backend.voltage

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 10

        VoltageGauge {
            anchors.horizontalCenter: parent.horizontalCenter
            gaugeSource: "../../assets/cadran_voltmetre.png"
            gaugeSource1: "../../assets/cadran_voltmetre1.png"
            width: 380
            height: 380
            value: voltagePage.voltage
            maximum: 20
        }
    }
}
