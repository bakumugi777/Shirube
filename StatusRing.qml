import QtQuick

Item {
    id: root
    required property string symbol
    required property real value
    required property string accessibleName
    property string caption: ""
    property bool subdued: false
    property bool expanded: false
    property real expansionGlow: expanded ? 1.0 : 0.0
    property bool wheelEnabled: false
    readonly property real ringDiameter: 46
    readonly property bool hovered: interaction.containsMouse
    signal activated()
    signal wheelAdjusted(real steps)

    implicitWidth: ringDiameter
    implicitHeight: caption.length > 0 ? ringDiameter + 11 : ringDiameter
    opacity: expanded ? 1.0
                      : hovered ? Config.hoverOpacity
                      : subdued ? Config.subduedOpacity : Config.idleOpacity
    Accessible.name: accessibleName + " " + Math.round(value * 100) + "%"
    Accessible.role: Accessible.Indicator

    Behavior on opacity {
        NumberAnimation {
            duration: root.expanded ? 150 : 360
            easing.type: root.expanded ? Easing.OutCubic : Easing.InOutSine
        }
    }

    Item {
        anchors.fill: parent
        transform: FloatingMotion {
            period: Config.floatingPeriodMs
                  + (root.symbol.charCodeAt(0) % 5) * 370
            reverse: root.symbol.charCodeAt(0) % 2 === 0
        }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const center = width / 2;
            const ringHeight = root.caption.length > 0 ? root.ringDiameter : height;
            const ringCenterY = ringHeight / 2;
            const radius = Math.min(width, ringHeight) / 2 - 5;
            const start = -Math.PI / 2;
            const span = Math.PI * 2;
            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineWidth = 1.25;
            ctx.strokeStyle = Config.ringTrackActiveColor;
            // A segmented guide reads as a quiet HUD instrument rather than a
            // smartwatch-style donut.
            const segments = 4;
            const gap = 0.13;
            for (let i = 0; i < segments; ++i) {
                const segmentStart = start + span * i / segments + gap;
                const segmentEnd = start + span * (i + 1) / segments - gap;
                ctx.beginPath();
                ctx.arc(center, ringCenterY, radius, segmentStart, segmentEnd);
                ctx.stroke();
            }
            if (root.value > 0.002) {
                // Diffuse light around the progress stroke. Multiple soft
                // orbits read as emitted light without forming a solid donut.
                ctx.lineCap = "round";
                ctx.lineWidth = 5.2 + 1.8 * root.expansionGlow;
                ctx.strokeStyle = Qt.rgba(Config.accentColor.r,
                                          Config.accentColor.g,
                                          Config.accentColor.b,
                                          (0.22 + 0.06 * root.expansionGlow)
                                          * Config.glowIntensity);
                ctx.beginPath();
                ctx.arc(center, ringCenterY, radius, start,
                        start + span * Math.max(0, Math.min(1, root.value)));
                ctx.stroke();

                ctx.lineWidth = 1.65;
                ctx.strokeStyle = root.subdued
                                ? Qt.rgba(Config.accentColor.r,
                                          Config.accentColor.g,
                                          Config.accentColor.b, 0.38)
                                : Config.accentColor;
                ctx.beginPath();
                ctx.arc(center, ringCenterY, radius, start,
                        start + span * Math.max(0, Math.min(1, root.value)));
                ctx.stroke();
            }

            // A second incomplete orbit adds instrument depth without becoming
            // another progress circle.
            ctx.lineWidth = 0.55;
            ctx.strokeStyle = Config.ringInnerColor;
            ctx.beginPath();
            ctx.arc(center, ringCenterY, radius - 7, -Math.PI * 0.82, Math.PI * 0.18);
            ctx.stroke();
        }

        Connections {
            target: root
            function onValueChanged() { canvas.requestPaint(); }
            function onSubduedChanged() { canvas.requestPaint(); }
            function onHoveredChanged() { canvas.requestPaint(); }
            function onExpandedChanged() { canvas.requestPaint(); }
            function onExpansionGlowChanged() { canvas.requestPaint(); }
        }
        Connections {
            target: Config
            function onAccentColorChanged() { canvas.requestPaint(); }
            function onRingTrackColorChanged() { canvas.requestPaint(); }
            function onRingTrackActiveColorChanged() { canvas.requestPaint(); }
            function onRingInnerColorChanged() { canvas.requestPaint(); }
            function onGlowIntensityChanged() { canvas.requestPaint(); }
        }
    }

    Text {
        x: (parent.width - width) / 2
        y: root.ringDiameter / 2 - height / 2
        text: root.symbol
        color: Config.accentColor
        opacity: Math.min(0.48, ((root.hovered ? 0.30
                              : root.subdued ? 0.10 : 0.24)
                              + 0.10 * root.expansionGlow)
                              * Config.glowIntensity * Config.textGlowIntensity)
        scale: root.hovered ? 1.24 : 1.18 + 0.06 * root.expansionGlow
        style: Text.Outline
        styleColor: Config.accentColor
        font { family: Config.resolvedFontFamily; pixelSize: Config.moduleFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
    }

    Text {
        x: (parent.width - width) / 2
        y: root.ringDiameter / 2 - height / 2
        text: root.symbol
        color: root.subdued ? Config.subduedTextColor : Config.brightTextColor
        style: Text.Outline
        styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g,
                            Config.accentColor.b,
                            Math.min(1.0, ((root.subdued ? 0.26 : 0.64)
                          + 0.24 * root.expansionGlow) * Config.glowIntensity))
        font { family: Config.resolvedFontFamily; pixelSize: Config.moduleFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
    }

    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        visible: root.caption.length > 0
        text: root.caption
        color: Config.captionColor
        opacity: 0.72
        style: Text.Outline
        styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g,
                            Config.accentColor.b, Math.min(1.0,
                            (0.32 + 0.20 * root.expansionGlow) * Config.glowIntensity))
        font {
            family: Config.resolvedFontFamily
            pixelSize: 8
            weight: Font.Medium
            letterSpacing: 2.2
        }
    }

    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onWheel: wheel => {
            if (!root.wheelEnabled) {
                wheel.accepted = false;
                return;
            }
            const delta = wheel.angleDelta.y !== 0
                        ? wheel.angleDelta.y / 120
                        : wheel.pixelDelta.y / 40;
            if (delta !== 0)
                root.wheelAdjusted(delta);
            wheel.accepted = true;
        }
    }
}
