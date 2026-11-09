import QtQuick
import QtQuick.Controls

Button {
    id: control
    property color primaryColor: "#2d5fff"
    property color fillColor: "#1b2027"
    property color checkedColor: primaryColor
    property color iconTint: "#ffffff"
    property bool primary: false

    implicitWidth: 120
    implicitHeight: 60
    font.pixelSize: 18
    font.weight: Font.Medium
    icon.width: 28
    icon.height: 28
    icon.color: (checked || primary) ? "#0d1014" : iconTint
    palette.buttonText: (checked || primary) ? "#0d1014" : "#ffffff"

    opacity: enabled ? 1.0 : 0.4
    scale: down ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: 90 } }

    background: Rectangle {
        radius: 14
        border.width: 1
        border.color: (control.checked || control.primary) ? "transparent" : "#2c333c"
        color: {
            if (control.checked) return control.checkedColor
            if (control.primary) return control.fillColor
            return control.down ? "#2c333c" : control.fillColor
        }
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
