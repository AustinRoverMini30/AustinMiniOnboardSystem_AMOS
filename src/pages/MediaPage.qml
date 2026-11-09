import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "../components"

Item {
    id: mediaPage
    property color primaryColor: "#2d5fff"
    property var selectedAlbum: null
    property var playbackTracks: []
    property string playbackAlbumName: ""
    property int currentTrackIndex: -1

    function playTrack(index) {
        if (!selectedAlbum || index < 0 || index >= selectedAlbum.tracks.length)
            return
        playbackTracks = selectedAlbum.tracks
        playbackAlbumName = selectedAlbum.name
        playQueuedTrack(index)
    }

    function playQueuedTrack(index) {
        if (index < 0 || index >= playbackTracks.length)
            return
        currentTrackIndex = index
        audioPlayer.source = playbackTracks[index].url
        audioPlayer.play()
    }

    function nextTrack() {
        if (playbackTracks.length > 0)
            playQueuedTrack((currentTrackIndex + 1) % playbackTracks.length)
    }

    function previousTrack() {
        if (playbackTracks.length > 0)
            playQueuedTrack((currentTrackIndex - 1 + playbackTracks.length)
                            % playbackTracks.length)
    }

    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                mediaPage.nextTrack()
        }
        onErrorOccurred: (error, errorString) => {
            console.warn("Audio :", errorString)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 108
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            EurostileText {
                Layout.fillWidth: true
                color: "#ffffff"
                font.pixelSize: 28
                font.weight: Font.DemiBold
                text: "Lecteur multimédia"
            }

            DashButton {
                primaryColor: mediaPage.primaryColor
                visible: mediaPage.selectedAlbum !== null
                implicitWidth: 104
                implicitHeight: 38
                font.pixelSize: 15
                text: "Albums"
                onClicked: mediaPage.selectedAlbum = null
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: "#13181e"
            border.width: 1
            border.color: "#2c333c"
            clip: true

            EurostileText {
                anchors.centerIn: parent
                visible: backend.musicAlbums.length === 0
                color: "#8a93a0"
                font.pixelSize: 18
                text: "Aucun album trouvé dans le dossier music"
            }

            GridView {
                id: albumGrid
                anchors.fill: parent
                anchors.margins: 10
                visible: mediaPage.selectedAlbum === null && backend.musicAlbums.length > 0
                clip: true
                cellWidth: width / 4
                cellHeight: cellWidth
                model: backend.musicAlbums
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Image {
                    id: albumCover
                    required property var modelData
                    width: albumGrid.cellWidth - 10
                    height: albumGrid.cellHeight - 10
                    source: modelData.cover
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: mediaPage.primaryColor
                        visible: albumCover.status !== Image.Ready

                        EurostileText {
                            anchors.centerIn: parent
                            color: "#0d1014"
                            font.pixelSize: 48
                            text: "♪"
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "transparent"
                        border.width: 1
                        border.color: "#2c333c"
                    }

                    TapHandler {
                        onTapped: mediaPage.selectedAlbum = albumCover.modelData
                    }
                }
            }

            ListView {
                id: trackList
                anchors.fill: parent
                anchors.margins: 10
                visible: mediaPage.selectedAlbum !== null
                clip: true
                spacing: 4
                model: mediaPage.selectedAlbum ? mediaPage.selectedAlbum.tracks : []
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: trackRow
                    required property var modelData
                    width: trackList.width
                    height: 42
                    radius: 8
                    color: mediaPage.selectedAlbum
                           && mediaPage.playbackAlbumName === mediaPage.selectedAlbum.name
                           && mediaPage.currentTrackIndex === trackRow.modelData.number - 1
                           ? "#252d38" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        EurostileText {
                            Layout.preferredWidth: 30
                            color: mediaPage.primaryColor
                            font.pixelSize: 15
                            text: mediaPage.selectedAlbum
                                  && mediaPage.playbackAlbumName === mediaPage.selectedAlbum.name
                                  && mediaPage.currentTrackIndex
                                     === trackRow.modelData.number - 1
                                  ? "♪" : trackRow.modelData.number
                        }
                        EurostileText {
                            Layout.fillWidth: true
                            color: "#ffffff"
                            font.pixelSize: 16
                            elide: Text.ElideRight
                            text: trackRow.modelData.title
                        }
                    }

                    TapHandler {
                        onTapped: mediaPage.playTrack(trackRow.modelData.number - 1)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            radius: 12
            color: "#1b2027"
            border.width: 1
            border.color: "#2c333c"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    EurostileText {
                        Layout.fillWidth: true
                        color: "#ffffff"
                        font.pixelSize: 15
                        elide: Text.ElideRight
                        text: mediaPage.currentTrackIndex >= 0
                              ? mediaPage.playbackTracks[mediaPage.currentTrackIndex].title
                              : "Aucune piste en cours"
                    }
                    EurostileText {
                        Layout.fillWidth: true
                        color: "#8a93a0"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        text: mediaPage.currentTrackIndex >= 0
                              ? mediaPage.playbackAlbumName : "Choisissez un album"
                    }
                }

                DashButton {
                    primaryColor: mediaPage.primaryColor
                    implicitWidth: 52
                    implicitHeight: 48
                    font.pixelSize: 22
                    text: "‹"
                    enabled: mediaPage.playbackTracks.length > 0
                    onClicked: mediaPage.previousTrack()
                }

                DashButton {
                    primaryColor: mediaPage.primaryColor
                    implicitWidth: 58
                    implicitHeight: 48
                    font.pixelSize: 19
                    text: audioPlayer.playbackState === MediaPlayer.PlayingState ? "Ⅱ" : "▶"
                    enabled: backend.musicAlbums.length > 0
                    primary: true
                    fillColor: mediaPage.primaryColor
                    onClicked: {
                        if (audioPlayer.playbackState === MediaPlayer.PlayingState) {
                            audioPlayer.pause()
                        } else if (mediaPage.currentTrackIndex >= 0) {
                            audioPlayer.play()
                        } else if (mediaPage.selectedAlbum
                                   && mediaPage.selectedAlbum.tracks.length > 0) {
                            mediaPage.playTrack(0)
                        } else if (backend.musicAlbums.length > 0) {
                            mediaPage.selectedAlbum = backend.musicAlbums[0]
                            mediaPage.playTrack(0)
                        }
                    }
                }

                DashButton {
                    primaryColor: mediaPage.primaryColor
                    implicitWidth: 52
                    implicitHeight: 48
                    font.pixelSize: 22
                    text: "›"
                    enabled: mediaPage.playbackTracks.length > 0
                    onClicked: mediaPage.nextTrack()
                }
            }
        }
    }
}
