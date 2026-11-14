import QtQuick
import QtMultimedia
import "../components"

Item {
    id: voltagePage
    property real voltage: backend.voltage
    property bool busAvailable: backend.busAvailable

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 10

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380
            height: 380

            VoltageGauge {
                anchors.fill: parent
                visible: voltagePage.busAvailable
                gaugeSource: "../../assets/cadran_voltmetre.png"
                gaugeSource1: "../../assets/cadran_voltmetre1.png"
                value: voltagePage.voltage
                maximum: 20
            }

            VideoOutput {
                id: failureVideoOutput
                anchors.fill: parent
                visible: !voltagePage.busAvailable
                fillMode: VideoOutput.PreserveAspectFit
            }
        }
    }

    MediaPlayer {
        id: failureVideoPlayer
        source: voltagePage.busAvailable ? "" : "../../assets/voltmeter_fail.mp4"
        videoOutput: failureVideoOutput
        audioOutput: AudioOutput { muted: true }
        loops: MediaPlayer.Infinite

        onErrorOccurred: (error, errorString) => {
            console.error("Erreur vidéo du voltmètre :", error, errorString)
        }
    }

    Component.onCompleted: {
        if (!busAvailable)
            failureVideoPlayer.play()
    }

    onBusAvailableChanged: {
        if (busAvailable)
            failureVideoPlayer.stop()
        else
            failureVideoPlayer.play()
    }
}
