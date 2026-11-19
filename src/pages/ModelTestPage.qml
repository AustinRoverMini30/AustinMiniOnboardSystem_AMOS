import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils

Item {
    id: modelPage
    property color primaryColor: "#2d5fff"
    // "x" uses vertical drags and leaves horizontal drags for SwipeView; "y" or "z" uses horizontal drags.
    property string rotationAxis: "y"

    function rotate(amount) {
        var rotation = Qt.vector3d(
            modelRotation.eulerRotation.x,
            modelRotation.eulerRotation.y,
            modelRotation.eulerRotation.z
        )
        if (rotationAxis === "x")
            rotation.x += amount
        else if (rotationAxis === "y")
            rotation.y += amount
        else
            rotation.z += amount
        modelRotation.eulerRotation = rotation
    }

    Rectangle {
        id: modelFrame
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 108
        radius: 16
        color: "#11161d"
        border.width: 1
        border.color: "#2c333c"
        clip: true

        View3D {
            id: modelView
            anchors.fill: parent
            anchors.margins: 2
            camera: viewCamera
            environment: SceneEnvironment {
                clearColor: "transparent"
                backgroundMode: SceneEnvironment.Transparent
            }

            PerspectiveCamera {
                id: viewCamera
                position: Qt.vector3d(0, 35, 130)
                eulerRotation: Qt.vector3d(-15, 0, 0)
                clipNear: 0.1
                clipFar: 5000
            }

            DirectionalLight {
                eulerRotation: Qt.vector3d(-35, -35, 0)
                brightness: 1.4
            }

            DirectionalLight {
                eulerRotation: Qt.vector3d(145, 30, 0)
                brightness: 0.6
            }

            Node {
                id: modelRotation
                eulerRotation: Qt.vector3d(0, 0, 0)

                Node {
                    position: Qt.vector3d(
                        -(modelLoader.bounds.minimum.x + modelLoader.bounds.maximum.x) / 2,
                        -(modelLoader.bounds.minimum.y + modelLoader.bounds.maximum.y) / 2,
                        -(modelLoader.bounds.minimum.z + modelLoader.bounds.maximum.z) / 2
                    )

                    RuntimeLoader {
                        id: modelLoader
                        source: backend.stlModelUrl
                        scale: {
                            var bounds = modelLoader.bounds
                            var largestDimension = Math.max(
                                bounds.maximum.x - bounds.minimum.x,
                                bounds.maximum.y - bounds.minimum.y,
                                bounds.maximum.z - bounds.minimum.z
                            )
                            var factor = largestDimension > 0 ? 120 / largestDimension : 1
                            return Qt.vector3d(factor, factor, factor)
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real previousX: 0
                property real previousY: 0

                onPressed: function(mouse) {
                    previousX = mouse.x
                    previousY = mouse.y
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return
                    var delta = modelPage.rotationAxis === "x"
                               ? mouse.y - previousY : mouse.x - previousX
                    modelPage.rotate(delta * 0.7)
                    previousX = mouse.x
                    previousY = mouse.y
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: backend.stlModelError.length > 0 || modelLoader.status === RuntimeLoader.Error
                       ? "#e5484d" : "#8a93a0"
                font.pixelSize: 16
                visible: backend.stlModelError.length > 0 || modelLoader.status !== RuntimeLoader.Success
                text: backend.stlModelError.length > 0
                      ? backend.stlModelError
                      : modelLoader.status === RuntimeLoader.Error
                        ? modelLoader.errorString
                        : "Chargement du modèle..."
            }
        }
    }
}
