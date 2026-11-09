import QtQuick
import QtMultimedia

Rectangle {
    id: overlay
    property bool holdLastFrame: false
    property int timeout: 0
    property int fadeDuration: 400

    color: "black"
    visible: false

    function start() {
        if (backend.bootVideoUrl.toString() === "") {
            visible = false
            return
        }
        fade.stop()
        opacity = 1
        visible = true
        player.source = backend.bootVideoUrl
        player.play()
        if (timeout > 0) safety.restart()
    }

    function finish() {
        if (!visible) return
        safety.stop()
        fade.restart()
    }

    MediaPlayer {
        id: player
        videoOutput: video
        audioOutput: AudioOutput {}

        function freeze() {
            position = Math.max(0, duration - 100)
            pause()
        }

        onPositionChanged: {
            if (overlay.holdLastFrame && duration > 0 && position >= duration - 150)
                freeze()
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (overlay.holdLastFrame) freeze()
                else overlay.finish()
            }
        }
        onErrorOccurred: (error, errorString) => {
            console.warn("Vidéo :", errorString)
            overlay.finish()
        }
    }

    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MouseArea { anchors.fill: parent; onClicked: overlay.finish() }

    Timer {
        id: safety
        interval: overlay.timeout
        onTriggered: overlay.finish()
    }

    NumberAnimation {
        id: fade
        target: overlay
        property: "opacity"
        to: 0
        duration: overlay.fadeDuration
        onFinished: {
            player.stop()
            player.source = ""
            overlay.visible = false
            overlay.opacity = 1
        }
    }
}
