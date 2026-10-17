import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 800; height: 480
    visible: true
    color: "#0d1014"
    title: "Mini Dash"

    // Bouton réutilisable : un seul endroit pour le style
    component DashButton: Button {
        id: control
        property color fillColor: "#1b2027"
        property color checkedColor: "#3ecf8e"
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

    component GaugeView: Item {
        id: gaugeView
        property url gaugeSource
        property string title: ""
        property real value: 0
        property real maximum: 100
        property real gaugeSize: Math.min(width, height - 44)

        function clampedValue() {
            return Math.max(0, Math.min(value, maximum))
        }

        function needleRotation() {
            return -(50 - (clampedValue() * 25 / 10))
        }

        Image {
            id: gaugeImage
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: gaugeView.gaugeSize
            height: width
            source: gaugeView.gaugeSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Image {
            anchors.centerIn: gaugeImage
            width: gaugeImage.width * 0.88
            height: width * 0.17
            source: "../assets/Aiguille.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            transformOrigin: Item.Center
            rotation: gaugeView.needleRotation()
        }

        Text {
            anchors.top: gaugeImage.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.pixelSize: 17
            font.weight: Font.Medium
            text: gaugeView.title
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            color: "#8a93a0"
            font.pixelSize: 14
            text: gaugeView.value.toFixed(0) + (gaugeView.title === "TEMPÉRATURE" ? " °C" : " %")
        }
    }

        // Champ de saisie lecture seule, piloté par le pavé numérique
    component JournalField: TextField {
        id: field
        property bool active: false
        property string unit: ""
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
            border.color: field.active ? "#3ecf8e" : "#2c333c"
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: field.active ? "#3ecf8e" : "#5b6571"
            font.pixelSize: 16
            text: field.unit
        }

        TapHandler { onTapped: field.selected() }
    }

    // Fond en léger dégradé
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#171c23" }
            GradientStop { position: 1.0; color: "#0d1014" }
        }
    }

    SwipeView {
        id: swipe
        anchors.fill: parent

        // Page 1 : horloge
        Item {
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -30
                spacing: 24

                Text {
                    id: clock
                    Layout.alignment: Qt.AlignHCenter
                    color: "#ffffff"
                    font.pixelSize: 160
                    font.weight: Font.Light
                    font.letterSpacing: 4
                    text: Qt.formatTime(new Date(), "hh:mm")
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }

            }
        }

        // Page 2 : cadrans
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 24
                anchors.bottomMargin: 108
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12

                Text {
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
                        gaugeSource: "../assets/Compteur.png"
                        title: "TEMPÉRATURE"
                        value: backend.temperature
                        maximum: 100
                    }
                    GaugeView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        gaugeSource: "../assets/CompteurCpu.png"
                        title: "CPU"
                        value: backend.cpuUsage
                        maximum: 100
                    }
                    GaugeView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        gaugeSource: "../assets/CompteurRam.png"
                        title: "RAM"
                        value: backend.ramUsage
                        maximum: 100
                    }
                }
            }
        }

        // Page 3 : carnet de bord
        Item {
            id: journalPage
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
                anchors.bottomMargin: 108   // laisse la place aux points et aux boutons du bas
                spacing: 10

                // En-tête
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    Text {
                        Layout.fillWidth: true
                        color: "#ffffff"
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        text: journalPage.showHistory ? "Historique" : "Carnet de bord"
                    }

                    DashButton {
                        implicitWidth: 140
                        implicitHeight: 40
                        font.pixelSize: 16
                        text: journalPage.showHistory ? "Saisie" : "Historique"
                        onClicked: journalPage.showHistory = !journalPage.showHistory
                    }
                }

                // Champs
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    spacing: 10
                    visible: !journalPage.showHistory

                    JournalField {
                        id: mileageField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Kilométrage"
                        unit: "km"
                        active: journalPage.activeField === mileageField
                        onSelected: journalPage.activeField = mileageField
                    }
                    JournalField {
                        id: litresField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Litres"
                        unit: "L"
                        active: journalPage.activeField === litresField
                        onSelected: journalPage.activeField = litresField
                    }
                    JournalField {
                        id: priceField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Prix"
                        unit: "€"
                        active: journalPage.activeField === priceField
                        onSelected: journalPage.activeField = priceField
                    }
                }

                // Pavé + résumé / actions
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

                        // Carte de synthèse
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

                                Text {
                                    color: "#8a93a0"
                                    font.pixelSize: 12
                                    text: "MOYENNE"
                                }
                                Text {
                                    color: "#3ecf8e"
                                    font.pixelSize: 26
                                    font.weight: Font.DemiBold
                                    text: backend.journalRows.length < 1
                                          ? "--"
                                          : backend.journalAverage.toFixed(2) + " L/100"
                                }
                                Text {
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
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: "Valider"
                            font.pixelSize: 22
                            primary: true
                            fillColor: "#3ecf8e"
                            onClicked: {
                                if (backend.saveJournalEntry(
                                        mileageField.text, litresField.text, priceField.text)) {
                                    journalPage.clearFields()
                                }
                            }
                        }

                        DashButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            text: "Effacer"
                            onClicked: journalPage.clearFields()
                        }
                    }
                }

                // Historique
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: journalPage.showHistory
                    radius: 14
                    color: "#13181e"
                    border.width: 1
                    border.color: "#2c333c"

                    Text {
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
                            width: journalList.width
                            height: 46
                            radius: 10
                            color: "#1b2027"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    Layout.fillWidth: true
                                    color: "#ffffff"
                                    font.pixelSize: 17
                                    text: modelData.date
                                }
                                Text {
                                    color: "#8a93a0"
                                    font.pixelSize: 15
                                    text: modelData.distance.toFixed(0) + " km"
                                }
                                Text {
                                    Layout.preferredWidth: 130
                                    horizontalAlignment: Text.AlignRight
                                    color: "#3ecf8e"
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

        // Page 2 : mise à jour
        Item {
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -40
                width: parent.width * 0.8
                spacing: 18

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: "#ffffff"
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                    text: "Mise à jour"
                }

                Text {
                    Layout.fillWidth: true
                    color: "#8a93a0"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: "Version installée : " + backend.currentVersion
                }

                Text {
                    Layout.fillWidth: true
                    color: backend.latestVersion ? "#3ecf8e" : "#ffffff"
                    font.pixelSize: 22
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: backend.latestVersion
                        ? "Nouvelle version : " + backend.latestVersion
                        : backend.updateStatus
                }

                ProgressBar {
                    id: bar
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: backend.updateProgress
                    visible: backend.updateInProgress

                    background: Rectangle {
                        implicitHeight: 8
                        radius: 4
                        color: "#252a31"
                    }
                    contentItem: Item {
                        Rectangle {
                            width: bar.visualPosition * parent.width
                            height: parent.height
                            radius: 4
                            color: "#3ecf8e"
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    color: "#8a93a0"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: backend.updateStatus
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    spacing: 16

                    DashButton {
                        text: "Rechercher"
                        implicitWidth: 170
                        enabled: !backend.updateInProgress
                        onClicked: backend.checkForUpdates()
                    }

                    DashButton {
                        text: backend.updateInProgress ? "En cours..." : "Télécharger"
                        implicitWidth: 170
                        primary: true
                        fillColor: "#3ecf8e"
                        enabled: backend.updateAvailable && !backend.updateInProgress
                        onClicked: backend.startUpdate()
                    }
                }
            }
        }
    }

    // Les points sont placés au-dessus des boutons du bas
    PageIndicator {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 94
        anchors.horizontalCenter: parent.horizontalCenter
        count: swipe.count
        currentIndex: swipe.currentIndex

        delegate: Rectangle {
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: index === swipe.currentIndex ? "#3ecf8e" : "#3a424d"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 20

        DashButton {
            id: fanButton
            checkable: true

            contentItem: Item {
                Image {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    source: "../assets/fan.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: fanButton.checked
                    }
                }
            }
        }

        DashButton {
            id: onOffButton
            icon.source: "../assets/on-off-button.png"
            onClicked: powerDialog.open()
        }
    }

    Dialog {
        id: powerDialog
        title: "Alimentation"
        modal: true
        anchors.centerIn: parent
        width: 360
        padding: 24

        Overlay.modal: Rectangle { color: "#b0000000" }

        background: Rectangle {
            radius: 20
            color: "#1b2027"
            border.width: 1
            border.color: "#2c333c"
        }

        header: Text {
            topPadding: 24
            color: "#ffffff"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            text: powerDialog.title
        }

        contentItem: ColumnLayout {
            spacing: 20

            Text {
                Layout.fillWidth: true
                color: "#8a93a0"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                text: "Éteindre le système ?"
            }

            DashButton {
                Layout.fillWidth: true
                text: "Éteindre"
                icon.source: "../assets/on-off-button.png"
                primary: true
                fillColor: "#e5484d"
                palette.buttonText: "#ffffff"
                icon.color: "#ffffff"
                onClicked: {
                    powerDialog.close()
                    backend.shutdown()
                }
            }
        }
    }
}