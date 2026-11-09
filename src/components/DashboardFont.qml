pragma Singleton
import QtQuick

QtObject {
    property FontLoader loader: FontLoader {
        source: "../../assets/fonts/eurostile-bold-extended.otf"
    }
    readonly property string family: loader.name
}
