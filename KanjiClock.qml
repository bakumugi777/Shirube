import QtQuick

Item {
    id: root
    required property date date
    property bool expanded: false
    property real expansionGlow: expanded ? 1.0 : 0.0
    readonly property bool hovered: interaction.containsMouse
    signal activated()

    readonly property var digits: ["零", "壱", "弐", "参", "肆", "伍", "陸", "漆", "捌", "玖"]
    readonly property string hourText: digits[Math.floor(date.getHours() / 10)] + digits[date.getHours() % 10]
    readonly property string minuteText: digits[Math.floor(date.getMinutes() / 10)] + digits[date.getMinutes() % 10]

    implicitWidth: 27
    implicitHeight: 99
    opacity: Config.idleOpacity
    Accessible.name: "Clock " + Qt.formatTime(date, "HH:mm")
    Accessible.role: Accessible.Button


    Item {
        anchors.fill: parent
        transform: FloatingMotion {
            period: Config.floatingPeriodMs + 940
            reverse: true
        }

    Canvas {
        id: clockGlow
        x: -8
        width: parent.width + 16
        height: parent.height

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const centers = [10, 29, 48, 68, 87];
            for (let i = 0; i < centers.length; ++i) {
                const halo = ctx.createRadialGradient(width / 2, centers[i], 1,
                                                      width / 2, centers[i], 19);
                halo.addColorStop(0.0, Qt.rgba(Config.accentColor.r,
                                               Config.accentColor.g,
                                               Config.accentColor.b, Math.min(1.0, (0.27 + 0.12 * root.expansionGlow) * Config.glowIntensity * Config.textGlowIntensity)));
                halo.addColorStop(0.42, Qt.rgba(Config.accentColor.r,
                                                Config.accentColor.g,
                                                Config.accentColor.b, Math.min(1.0, (0.13 + 0.07 * root.expansionGlow) * Config.glowIntensity * Config.textGlowIntensity)));
                halo.addColorStop(1.0, Qt.rgba(Config.accentColor.r,
                                               Config.accentColor.g,
                                               Config.accentColor.b, 0.0));
                ctx.fillStyle = halo;
                ctx.fillRect(0, Math.max(0, centers[i] - 19), width, 38);
            }
        }

        Connections {
            target: Config
            function onAccentColorChanged() { clockGlow.requestPaint(); }
            function onGlowIntensityChanged() { clockGlow.requestPaint(); }
            function onTextGlowIntensityChanged() { clockGlow.requestPaint(); }
        }
        Connections {
            target: root
            function onExpansionGlowChanged() { clockGlow.requestPaint(); }
        }
    }

    Column {
        anchors.centerIn: parent
        width: root.width
        spacing: 1

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.hourText.charAt(0)
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g, Config.accentColor.b, Math.min(1.0, (0.64 + 0.24 * root.expansionGlow) * Config.glowIntensity))
            font { family: Config.resolvedFontFamily; pixelSize: Config.clockFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.hourText.charAt(1)
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g, Config.accentColor.b, Math.min(1.0, (0.64 + 0.24 * root.expansionGlow) * Config.glowIntensity))
            font { family: Config.resolvedFontFamily; pixelSize: Config.clockFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
        }

        Item {
            width: parent.width
            height: 11

            Rectangle {
                anchors.centerIn: parent
                width: 9
                height: 9
                radius: 4.5
                color: Config.accentColor
                opacity: Math.min(0.30, 0.19 * Config.glowIntensity)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 3
                height: 3
                radius: 1.5
                color: Config.brightTextColor
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.minuteText.charAt(0)
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g, Config.accentColor.b, Math.min(1.0, (0.64 + 0.24 * root.expansionGlow) * Config.glowIntensity))
            font { family: Config.resolvedFontFamily; pixelSize: Config.clockFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.minuteText.charAt(1)
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g, Config.accentColor.b, Math.min(1.0, (0.64 + 0.24 * root.expansionGlow) * Config.glowIntensity))
            font { family: Config.resolvedFontFamily; pixelSize: Config.clockFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
        }
    }

    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
