/**
 * Pixie SDDM - PowerBar Component
 * Author: xCaptaiN09
 */
import QtQuick

Row {
    id: powerBarRoot
    spacing: 6
    height: 36

    property color textColor: "white"

    FontLoader { id: iconFont; source: "../assets/fonts/MaterialDesignIcons.ttf" }

    // Battery (With forced live updates)
    Row {
        id: batteryRow
        spacing: 5
        visible: typeof battery !== "undefined" && typeof battery.percent !== "undefined"
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: batteryText
            text: (typeof battery !== "undefined" ? battery.percent : "0") + "%"
            color: textColor
            font.pixelSize: 14
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: batteryIcon
            text: (typeof battery !== "undefined" && battery.charging) ? "󱐋" : "󰁹"
            color: textColor
            font.pixelSize: 18
            font.family: iconFont.name
            anchors.verticalCenter: parent.verticalCenter
        }

        // Bulletproof Live Update: SDDM sometimes fails to emit battery signals,
        // so we force a check every 5 seconds.
        Timer {
            interval: 5000
            running: typeof battery !== "undefined" && battery.present
            repeat: true
            onTriggered: {
                batteryText.text = battery.percent + "%"
                batteryIcon.text = battery.charging ? "󱐋" : "󰁹"
            }
        }
    }

    // Keyboard Layout
    Item {
        width: 36
        height: 36
        visible: typeof keyboard !== "undefined" && keyboard.layouts.length > 1
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: kbArea.pressed ? 0.22 : (kbArea.containsMouse ? 0.12 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: (typeof keyboard !== "undefined" && keyboard.layouts[keyboard.currentLayout]) ? keyboard.layouts[keyboard.currentLayout].shortName : "US"
            color: textColor
            font.pixelSize: 13
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
        }

        MouseArea {
            id: kbArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
    }

    // Suspend
    Item {
        width: 36
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: suspendArea.pressed ? 0.22 : (suspendArea.containsMouse ? 0.12 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: "󰤄"
            color: textColor
            font.pixelSize: 19
            font.family: iconFont.name
        }

        MouseArea {
            id: suspendArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: sddm.suspend()
        }
    }

    // Restart
    Item {
        width: 36
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: restartArea.pressed ? 0.22 : (restartArea.containsMouse ? 0.12 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: "󰑐"
            color: textColor
            font.pixelSize: 19
            font.family: iconFont.name
        }

        MouseArea {
            id: restartArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: sddm.reboot()
        }
    }

    // Shutdown
    Item {
        width: 36
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: shutdownArea.pressed ? 0.22 : (shutdownArea.containsMouse ? 0.12 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: "󰐥"
            color: textColor
            font.pixelSize: 19
            font.family: iconFont.name
        }

        MouseArea {
            id: shutdownArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: sddm.powerOff()
        }
    }
}
