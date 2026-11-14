import QtQuick
import "../components"

Item {
    id: voltagePage
    property real voltage: backend.voltage
    property bool busAvailable: backend.busAvailable

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 10

        VoltageGauge {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380
            height: 380
            gaugeSource: "../../assets/cadran_voltmetre.png"
            gaugeSource1: "../../assets/cadran_voltmetre1.png"
            value: voltagePage.voltage
            maximum: 20
            failureMode: !voltagePage.busAvailable
        }
    }
}
