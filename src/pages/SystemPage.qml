import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    property color primaryColor: "#2d5fff"

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 24
        anchors.bottomMargin: 108
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        EurostileText {
            Layout.alignment: Qt.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 34
            font.weight: Font.DemiBold
            text: "Informations système"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            GaugeView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                gaugeSource: "../../assets/Compteur.png"
                title: "TEMPÉRATURE"
                unit: "°C"
                value: backend.temperature
                maximum: 100
            }
            GaugeView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                gaugeSource: "../../assets/CompteurCpu.png"
                title: "CPU"
                value: backend.cpuUsage
                maximum: 100
            }
            GaugeView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                gaugeSource: "../../assets/CompteurRam.png"
                title: "RAM"
                value: backend.ramUsage
                maximum: 100
            }
        }
    }
}
