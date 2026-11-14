import QtQuick
import QtQuick.Controls
import "."

TextField {
    id: field
    property bool active: false
    property string unit: ""
    property color primaryColor: "#2d5fff"
    signal selected()

    readOnly: true
    selectByMouse: false
    color: "#ffffff"
    placeholderTextColor: "#5b6571"
    font.pixelSize: 24
    font.weight: Font.Medium
    leftPadding: 14
    rightPadding: 44
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: 12
        color: "#13181e"
        border.width: field.active ? 2 : 1
        border.color: field.active ? field.primaryColor : "#2c333c"
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    EurostileText {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: field.active ? field.primaryColor : "#5b6571"
        font.pixelSize: 16
        text: field.unit
    }

    TapHandler { onTapped: field.selected() }
}
