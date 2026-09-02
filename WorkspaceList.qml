import QtQuick

Item {
    id: root
    required property var workspaces
    required property int activeWorkspace
    signal workspaceActivated(int number)

    readonly property var numerals: [
        "零", "壱", "弐", "参", "肆", "伍", "陸", "漆", "捌", "玖", "拾"
    ]

    function labelFor(number) {
        if (number >= 0 && number < numerals.length)
            return numerals[number];
        if (number < 20)
            return "拾" + numerals[number - 10];
        return String(number);
    }

    implicitWidth: 30
    implicitHeight: list.implicitHeight

    Column {
        id: list
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 5

        Repeater {
            model: root.workspaces

            delegate: Item {
                id: workspaceItem
                required property var modelData
                readonly property bool active: Number(modelData) === root.activeWorkspace
                readonly property bool hovered: mouse.containsMouse

                width: 28
                height: 26

                Item {
                    id: floatingVisual
                    anchors.fill: parent
                    readonly property bool active: workspaceItem.active
                    readonly property bool hovered: workspaceItem.hovered
                    readonly property var modelData: workspaceItem.modelData
                    transform: FloatingMotion {
                        period: Config.floatingPeriodMs
                              + (Number(workspaceItem.modelData) % 5) * 330
                        reverse: Number(workspaceItem.modelData) % 2 === 0
                    }

                Canvas {
                    id: activeLightPool
                    anchors.centerIn: parent
                    width: 36
                    height: 52
                    opacity: parent.active ? 1.0 : 0.0
                    visible: opacity > 0.01

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.save();
                        ctx.translate(width / 2, height / 2);
                        ctx.scale(0.56, 1.0);
                        const radius = height * 0.48;
                        const glow = ctx.createRadialGradient(0, 0, 0,
                                                              0, 0, radius);
                        glow.addColorStop(0.0, Qt.rgba(Config.accentColor.r,
                                                       Config.accentColor.g,
                                                       Config.accentColor.b,
                                                       Math.min(0.82, 0.58 * Config.glowIntensity)));
                        glow.addColorStop(0.46, Qt.rgba(Config.accentColor.r,
                                                        Config.accentColor.g,
                                                        Config.accentColor.b,
                                                        Math.min(0.42, 0.28 * Config.glowIntensity)));
                        glow.addColorStop(0.76, Qt.rgba(Config.accentColor.r,
                                                        Config.accentColor.g,
                                                        Config.accentColor.b,
                                                        Math.min(0.16, 0.10 * Config.glowIntensity)));
                        glow.addColorStop(1.0, Qt.rgba(Config.accentColor.r,
                                                       Config.accentColor.g,
                                                       Config.accentColor.b, 0));
                        ctx.fillStyle = glow;
                        ctx.fillRect(-radius, -radius, radius * 2, radius * 2);
                        ctx.restore();
                    }

                    onVisibleChanged: if (visible) requestPaint()
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
                    }
                    Connections {
                        target: Config
                        function onAccentColorChanged() { activeLightPool.requestPaint(); }
                        function onGlowIntensityChanged() { activeLightPool.requestPaint(); }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.active
                    text: root.labelFor(Number(parent.modelData))
                    color: Config.accentColor
                    opacity: 0.10 * Config.glowIntensity
                    scale: 1.46
                    style: Text.Outline
                    styleColor: Config.accentColor
                    font {
                        family: Config.resolvedFontFamily
                        pixelSize: Config.workspaceFontSize
                        weight: Font.DemiBold
                        letterSpacing: Config.letterSpacing
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !parent.active
                    text: root.labelFor(Number(parent.modelData))
                    color: Config.accentColor
                    opacity: Math.min(0.36, (parent.hovered ? 0.27 : 0.20)
                                              * Config.glowIntensity
                                              * Config.textGlowIntensity)
                    scale: parent.hovered ? 1.22 : 1.16
                    style: Text.Outline
                    styleColor: Config.accentColor
                    font {
                        family: Config.resolvedFontFamily
                        pixelSize: Config.workspaceFontSize
                        weight: Config.fontWeight
                        letterSpacing: Config.letterSpacing
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.active
                    text: root.labelFor(Number(parent.modelData))
                    color: Config.accentColor
                    opacity: 0.18 * Config.glowIntensity
                    scale: 1.28
                    style: Text.Outline
                    styleColor: Config.accentColor
                    font {
                        family: Config.resolvedFontFamily
                        pixelSize: Config.workspaceFontSize
                        weight: Font.DemiBold
                        letterSpacing: Config.letterSpacing
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.active
                    text: root.labelFor(Number(parent.modelData))
                    color: Config.accentColor
                    opacity: 0.30 * Config.glowIntensity
                    scale: 1.12
                    style: Text.Outline
                    styleColor: Config.accentColor
                    font {
                        family: Config.resolvedFontFamily
                        pixelSize: Config.workspaceFontSize
                        weight: Font.DemiBold
                        letterSpacing: Config.letterSpacing
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.labelFor(Number(parent.modelData))
                    opacity: parent.active ? 1.0 : parent.hovered ? 0.90 : 0.68
                    color: parent.active ? Config.brightTextColor
                                         : Config.workspaceActiveColor
                    style: Text.Outline
                    styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g,
                                        Config.accentColor.b,
                                        Math.min(1.0, (parent.active ? 0.88
                                      : 0.60)
                                      * Config.glowIntensity))
                    scale: parent.active ? 1.08 : 1.0
                    font {
                        family: Config.resolvedFontFamily
                        pixelSize: Config.workspaceFontSize
                        weight: parent.active ? Font.DemiBold : Config.fontWeight
                        letterSpacing: Config.letterSpacing
                    }

                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.workspaceActivated(Number(workspaceItem.modelData))
                }
            }
        }
    }

}
