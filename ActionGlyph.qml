import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var action
    readonly property string symbol: String(action.symbol || "・")
    readonly property string actionName: String(action.name || symbol)
    readonly property bool actionEnabled: action.enabled !== false
    readonly property bool hovered: interaction.containsMouse

    implicitWidth: 46
    implicitHeight: 42
    width: implicitWidth
    height: implicitHeight
    opacity: actionEnabled ? (hovered ? 1.0 : 0.86) : Config.subduedOpacity
    Accessible.name: actionName
    Accessible.role: Accessible.Button

    Behavior on opacity { NumberAnimation { duration: 140 } }

    Item {
        anchors.fill: parent
        transform: FloatingMotion {
            period: Config.floatingPeriodMs
                  + (root.symbol.charCodeAt(0) % 5) * 410
            reverse: root.symbol.charCodeAt(0) % 2 === 1
        }

    Text {
        anchors.centerIn: parent
        visible: root.actionEnabled
        text: root.symbol
        color: Config.accentColor
        opacity: Math.min(0.52, (root.hovered ? 0.34 : 0.24)
                                  * Config.glowIntensity
                                  * Config.textGlowIntensity)
        scale: root.hovered ? 1.26 : 1.18
        style: Text.Outline
        styleColor: Config.accentColor
        font {
            family: Config.resolvedFontFamily
            pixelSize: Number(root.action.size || Config.moduleFontSize + 2)
            weight: Font.DemiBold
            letterSpacing: Config.letterSpacing
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.symbol
        color: root.actionEnabled ? Config.brightTextColor
                                  : Config.subduedTextColor
        style: Text.Outline
        styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g,
                            Config.accentColor.b,
                            Math.min(1.0, (root.hovered ? 0.90 : 0.62)
                                          * Config.glowIntensity))
        font {
            family: Config.resolvedFontFamily
            pixelSize: Number(root.action.size || Config.moduleFontSize + 2)
            weight: Font.DemiBold
            letterSpacing: Config.letterSpacing
        }
    }

    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        enabled: root.actionEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.runAction()
    }

    function runAction() {
        if (!actionEnabled || actionProcess.running)
            return;
        const command = action.command;
        if (typeof command === "string" && command.trim().length > 0) {
            actionProcess.exec(["sh", "-c", command]);
        } else if (command !== undefined && command !== null
                   && typeof command.length === "number" && command.length > 0) {
            const argumentsList = [];
            for (let i = 0; i < command.length; ++i)
                argumentsList.push(String(command[i]));
            actionProcess.exec(argumentsList);
        }
    }

    Process {
        id: actionProcess
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    console.warn("Shirube action " + root.actionName + ": " + message);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("Shirube action " + root.actionName
                             + " exited with code " + exitCode);
        }
    }
}
