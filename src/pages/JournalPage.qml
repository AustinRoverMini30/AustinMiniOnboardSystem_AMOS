import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: journalPage
    property color primaryColor: "#2d5fff"
    property TextField activeField: mileageField
    property bool showHistory: false

    function addKey(key) {
        if (!activeField) return
        if (key === "<") {
            activeField.text = activeField.text.slice(0, -1)
        } else if (key === ".") {
            if (!activeField.text.includes(".")
                    && activeField.text.length > 0
                    && activeField !== mileageField
                    && activeField.text.length < fieldLimit(activeField)) {
                activeField.text += key
            }
        } else if (activeField.text.length < fieldLimit(activeField)) {
            activeField.text += key
        }
    }

    function fieldLimit(field) {
        if (field === mileageField) return 8
        if (field === litresField) return 6
        return 7
    }

    function clearFields() {
        mileageField.clear()
        litresField.clear()
        priceField.clear()
        activeField = mileageField
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 108
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            EurostileText {
                Layout.fillWidth: true
                color: "#ffffff"
                font.pixelSize: 30
                font.weight: Font.DemiBold
                text: journalPage.showHistory ? "Historique" : "Carnet de bord"
            }

            DashButton {
                primaryColor: journalPage.primaryColor
                implicitWidth: 140
                implicitHeight: 40
                font.pixelSize: 16
                text: journalPage.showHistory ? "Saisie" : "Historique"
                onClicked: journalPage.showHistory = !journalPage.showHistory
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: 10
            visible: !journalPage.showHistory

            JournalField {
                id: mileageField
                primaryColor: journalPage.primaryColor
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: "Kilométrage"
                unit: "km"
                active: journalPage.activeField === mileageField
                onSelected: journalPage.activeField = mileageField
            }
            JournalField {
                id: litresField
                primaryColor: journalPage.primaryColor
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: "Litres"
                unit: "L"
                active: journalPage.activeField === litresField
                onSelected: journalPage.activeField = litresField
            }
            JournalField {
                id: priceField
                primaryColor: journalPage.primaryColor
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: "Prix"
                unit: "€"
                active: journalPage.activeField === priceField
                onSelected: journalPage.activeField = priceField
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            visible: !journalPage.showHistory

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: ["7", "8", "9", "4", "5", "6", "1", "2", "3", ".", "0", "<"]

                    delegate: DashButton {
                        required property string modelData
                        primaryColor: journalPage.primaryColor

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 40
                        text: modelData === "<" ? "←" : modelData
                        font.pixelSize: 26
                        enabled: !(modelData === "."
                                   && journalPage.activeField === mileageField)
                        onClicked: journalPage.addKey(modelData)
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 210
                Layout.fillHeight: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: 14
                    color: "#13181e"
                    border.width: 1
                    border.color: "#2c333c"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2

                        EurostileText {
                            color: "#8a93a0"
                            font.pixelSize: 12
                            text: "MOYENNE"
                        }
                        EurostileText {
                            color: journalPage.primaryColor
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            text: !backend.journalAverageReady
                                  ? "--"
                                  : backend.journalAverage.toFixed(2) + " L/100"
                        }
                        EurostileText {
                            Layout.fillWidth: true
                            color: "#8a93a0"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            text: backend.journalRows.length < 1
                                  ? "Aucune entrée"
                                  : "Dernière " + backend.journalLast.toFixed(2)
                                    + "  •  " + backend.journalTotalKm.toFixed(0) + " km"
                        }
                    }
                }

                DashButton {
                    primaryColor: journalPage.primaryColor
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "Valider"
                    font.pixelSize: 22
                    primary: true
                    fillColor: journalPage.primaryColor
                    onClicked: {
                        if (backend.saveJournalEntry(
                                    mileageField.text, litresField.text, priceField.text)) {
                            journalPage.clearFields()
                        }
                    }
                }

                DashButton {
                    primaryColor: journalPage.primaryColor
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    text: "Effacer"
                    onClicked: journalPage.clearFields()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: journalPage.showHistory
            radius: 14
            color: "#13181e"
            border.width: 1
            border.color: "#2c333c"

            EurostileText {
                anchors.centerIn: parent
                visible: backend.journalRows.length < 1
                color: "#5b6571"
                font.pixelSize: 18
                text: "Aucune entrée pour le moment"
            }

            ListView {
                id: journalList
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 8
                model: backend.journalRows
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    width: journalList.width
                    height: 46
                    radius: 10
                    color: "#1b2027"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        EurostileText {
                            Layout.fillWidth: true
                            color: "#ffffff"
                            font.pixelSize: 17
                            text: modelData.date
                        }
                        EurostileText {
                            color: "#8a93a0"
                            font.pixelSize: 15
                            text: modelData.distance.toFixed(0) + " km"
                        }
                        EurostileText {
                            Layout.preferredWidth: 130
                            horizontalAlignment: Text.AlignRight
                            color: journalPage.primaryColor
                            font.pixelSize: 17
                            font.weight: Font.Medium
                            text: modelData.consumption.toFixed(2) + " L/100"
                        }
                    }
                }
            }
        }
    }
}
