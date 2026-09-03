import QtQuick

Item {
    id: root

    required property string moduleName
    property bool presented: false
    property real projectionOpacity: 1
    property real cpuUsage: 0
    property var cpuCoreUsage: []
    property real memoryUsage: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property real audioVolume: 0
    property real displayedAudioVolume: audioVolume
    property bool audioMuted: false
    property string networkName: ""
    property real batteryLevel: 0
    property string batteryStatus: ""
    property int batteryTimeMinutes: -1
    property date currentDate: new Date()
    property real tetherY: height / 2
    readonly property bool hovered: overlayHover.hovered
    signal audioVolumeRequested(real value)
    signal audioMuteRequested()

    Behavior on displayedAudioVolume {
        NumberAnimation {
            duration: Config.audioGaugeTransitionMs
            easing.type: Easing.OutCubic
        }
    }

    function heightForModule(name) {
        return name === "cpu" ? Math.max(140, 89 + cpuCoreRows * 16)
             : name === "audio" ? 238
             : name === "network" ? 164
             : name === "battery" ? 164
             : name === "calendar" ? 250
             : name === "memory" ? 182 : 154;
    }

    readonly property int cpuCoreColumns: Math.min(2, Math.max(1, cpuCoreUsage.length))
    readonly property int cpuCoreRows: Math.ceil(cpuCoreUsage.length / cpuCoreColumns)

    function widthForModule(name) {
        return name === "cpu" ? Math.max(174,
               68 + cpuCoreColumns * 50 + (cpuCoreColumns - 1) * 4)
             : name === "audio" ? 210
             : name === "network" ? 292
             : name === "battery" ? 240
             : name === "calendar" ? 274
             : name === "memory" ? 288 : 258;
    }

    // Rightmost occupied coordinate inside the projection. This measures the
    // information itself, not the maximum container reserved for long values.
    function contentReachForModule(name) {
        if (name === "cpu")
            return widthForModule(name) - 10;
        if (name === "memory")
            return Math.max(32 + memoryValue.implicitWidth,
                            34 + memoryUsageLabel.implicitWidth);
        if (name === "network")
            return Math.max(32 + Math.min(networkValue.implicitWidth,
                                          widthForModule(name) - 48),
                            34 + networkStateLabel.implicitWidth);
        if (name === "audio")
            return Math.max(89, 66 + audioValue.implicitWidth / 2);
        if (name === "battery")
            return Math.max(32 + batteryValue.implicitWidth,
                            34 + batteryStateLabel.implicitWidth,
                            34 + batteryTimeLabel.implicitWidth);
        if (name === "calendar")
            return 228;
        return widthForModule(name);
    }

    readonly property var calendarCells: {
        const year = currentDate.getFullYear();
        const month = currentDate.getMonth();
        const firstWeekday = new Date(year, month, 1).getDay();
        const cells = [];
        for (let i = 0; i < 42; ++i) {
            const value = new Date(year, month, 1 - firstWeekday + i);
            cells.push({
                day: value.getDate(),
                currentMonth: value.getMonth() === month,
                today: value.getFullYear() === currentDate.getFullYear()
                    && value.getMonth() === currentDate.getMonth()
                    && value.getDate() === currentDate.getDate()
            });
        }
        return cells;
    }

    function batteryStateText() {
        return batteryStatus === "Charging" ? "Charging"
             : batteryStatus === "Discharging" ? "On battery"
             : batteryStatus === "Full" ? "Fully charged"
             : batteryStatus === "Not charging" ? "Plugged in" : "Unknown";
    }

    function batteryTimeText() {
        if (batteryTimeMinutes < 0)
            return "";
        const hours = Math.floor(batteryTimeMinutes / 60);
        const minutes = batteryTimeMinutes % 60;
        const value = (hours > 0 ? hours + "h " : "")
                    + (minutes > 0 ? minutes + "m" : "");
        return batteryStatus === "Charging" ? value + " until full"
                                             : "About " + value + " remaining";
    }

    readonly property var daijiDigits: [
        "零", "壱", "弐", "参", "肆", "伍", "陸", "漆", "捌", "玖"
    ]
    readonly property var traditionalMonthNames: [
        "睦月", "如月", "弥生", "卯月", "皐月", "水無月",
        "文月", "葉月", "長月", "神無月", "霜月", "師走"
    ]

    function daijiFixed(number, digits) {
        const padded = String(number).padStart(digits, "0");
        let result = "";
        for (let i = 0; i < padded.length; ++i)
            result += daijiDigits[Number(padded.charAt(i))];
        return result;
    }

    implicitWidth: widthForModule(moduleName)
    implicitHeight: heightForModule(moduleName)
    width: presented ? implicitWidth : 0
    height: presented ? implicitHeight : 0
    visible: presented && moduleName.length > 0

    HoverHandler {
        id: overlayHover
    }

    Item {
        anchors.fill: parent
        opacity: root.projectionOpacity

    Canvas {
        id: projection
        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: Config
            function onLightNearColorChanged() { projection.requestPaint(); }
            function onLightMidColorChanged() { projection.requestPaint(); }
            function onAccentColorChanged() { projection.requestPaint(); }
            function onHologramPanelColorChanged() { projection.requestPaint(); }
            function onHologramPanelOpacityChanged() { projection.requestPaint(); }
            function onGlowIntensityChanged() { projection.requestPaint(); }
        }
        Connections {
            target: root
            function onModuleNameChanged() { projection.requestPaint(); }
            function onTetherYChanged() { projection.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            ctx.reset();

            // A low-density projected surface with no geometric perimeter.
            // Every edge is alpha-feathered so it cannot read as a card.
            const left = 28;
            const top = 7;
            const right = w - 5;
            const bottom = h - 7;
            const surfaceHeight = Math.max(1, bottom - top);
            const stripHeight = 2;
            for (let y = top; y < bottom; y += stripHeight) {
                const phase = Math.PI * (y - top + stripHeight * 0.5) / surfaceHeight;
                const vertical = Math.pow(Math.max(0, Math.sin(phase)), 0.48);
                const alpha = Config.hologramPanelOpacity * vertical;
                const surface = ctx.createLinearGradient(left, 0, right, 0);
                surface.addColorStop(0.0, Qt.rgba(Config.hologramPanelColor.r,
                                                  Config.hologramPanelColor.g,
                                                  Config.hologramPanelColor.b, 0));
                surface.addColorStop(0.10, Qt.rgba(Config.hologramPanelColor.r,
                                                   Config.hologramPanelColor.g,
                                                   Config.hologramPanelColor.b,
                                                   alpha * 0.68));
                surface.addColorStop(0.34, Qt.rgba(Config.hologramPanelColor.r,
                                                   Config.hologramPanelColor.g,
                                                   Config.hologramPanelColor.b,
                                                   alpha));
                surface.addColorStop(0.76, Qt.rgba(Config.hologramPanelColor.r,
                                                   Config.hologramPanelColor.g,
                                                   Config.hologramPanelColor.b,
                                                   alpha * 0.22));
                surface.addColorStop(1.0, Qt.rgba(Config.hologramPanelColor.r,
                                                  Config.hologramPanelColor.g,
                                                  Config.hologramPanelColor.b, 0));
                ctx.fillStyle = surface;
                ctx.fillRect(left, y, right - left, stripHeight + 0.5);
            }

            // A fading optical trace relates the thin projected surface to the
            // selected module without turning it into a separate sidebar.
            const tetherY = Math.max(8, Math.min(h - 8, root.tetherY));
            function paintTrace(lineWidth, alpha, core) {
                const trace = ctx.createLinearGradient(0, 0, 36, 0);
                const color = core ? Config.brightTextColor
                                   : Config.lightNearColor;
                trace.addColorStop(0.0, Qt.rgba(color.r, color.g, color.b,
                    Math.min(1.0, alpha * Config.glowIntensity)));
                trace.addColorStop(0.42, Qt.rgba(Config.lightMidColor.r,
                                                 Config.lightMidColor.g,
                                                 Config.lightMidColor.b,
                    Math.min(1.0, alpha * 0.58 * Config.glowIntensity)));
                trace.addColorStop(1.0, Qt.rgba(Config.lightMidColor.r,
                                                Config.lightMidColor.g,
                                                Config.lightMidColor.b, 0));
                ctx.strokeStyle = trace;
                ctx.lineWidth = lineWidth;
                ctx.beginPath();
                ctx.moveTo(0, tetherY);
                ctx.lineTo(36, tetherY);
                ctx.stroke();
            }
            paintTrace(5.0, 0.13, false);
            paintTrace(2.4, 0.28, false);
            paintTrace(0.8, 0.78, true);

            const sourceHalo = ctx.createRadialGradient(2, tetherY, 0,
                                                         2, tetherY, 8);
            sourceHalo.addColorStop(0.0, Qt.rgba(Config.lightNearColor.r,
                                                 Config.lightNearColor.g,
                                                 Config.lightNearColor.b,
                                                 Math.min(1.0, 0.50 * Config.glowIntensity)));
            sourceHalo.addColorStop(1.0, Qt.rgba(Config.lightNearColor.r,
                                                 Config.lightNearColor.g,
                                                 Config.lightNearColor.b, 0));
            ctx.fillStyle = sourceHalo;
            ctx.fillRect(0, tetherY - 8, 10, 16);
            ctx.fillStyle = Config.brightTextColor;
            ctx.beginPath();
            ctx.arc(1.5, tetherY, 1.25, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    Item {
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        visible: root.moduleName === "cpu"

        Text {
            x: 32
            y: 29
            text: Math.round(root.cpuUsage * 100) + "%"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 24; weight: Font.DemiBold }
        }
        Grid {
            x: 32
            y: 65
            width: parent.width - 42
            columns: root.cpuCoreColumns
            rowSpacing: 5
            columnSpacing: 4

            Repeater {
                model: root.cpuCoreUsage

                Text {
                    required property real modelData
                    required property int index
                    width: (parent.width - (root.cpuCoreColumns - 1) * parent.columnSpacing)
                         / root.cpuCoreColumns
                    text: "C" + index + "  " + Math.round(modelData * 100) + "%"
                    color: Config.brightTextColor
                    opacity: 0.96
                    style: Text.Outline
                    styleColor: Config.accentColor
                    font { family: Config.resolvedFontFamily; pixelSize: 10; weight: Font.Medium }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleName === "memory"

        Text {
            id: memoryValue
            x: 32
            y: 55
            text: root.memoryUsedGiB.toFixed(1) + " / " + root.memoryTotalGiB.toFixed(1) + " GiB"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 16; weight: Font.DemiBold }
        }
        Text {
            id: memoryUsageLabel
            x: 34
            y: 91
            text: "Usage  " + Math.round(root.memoryUsage * 100) + "%"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 14; weight: Font.DemiBold }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleName === "network"

        Text {
            id: networkValue
            x: 32
            y: 57
            width: parent.width - 48
            elide: Text.ElideRight
            text: root.networkName.length > 0 ? root.networkName : "Disconnected"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
            id: networkStateLabel
            x: 34
            y: 96
            text: root.networkName.length > 0 ? "Connected" : "No active connection"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 14; weight: Font.DemiBold }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleName === "audio"

        Text {
            id: audioValue
            anchors.horizontalCenter: gauge.horizontalCenter
            y: 55
            text: root.audioMuted ? "MUTED" : Math.round(root.audioVolume * 100) + "%"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 20; weight: Font.DemiBold }

            MouseArea {
                id: audioMuteMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.audioMuteRequested()
            }
        }

        Item {
            id: gauge
            x: 53
            y: 91
            width: 26
            height: 122

            Canvas {
                id: volumeGlow
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    const w = width;
                    const h = height;
                    const center = w / 2;
                    const fillHeight = Math.max(2, h * root.displayedAudioVolume);
                    const top = h - fillHeight;
                    ctx.reset();

                    // The inactive path is a thin optical trace whose light
                    // vanishes before reaching either horizontal edge.
                    const track = ctx.createLinearGradient(0, 0, w, 0);
                    track.addColorStop(0.0, Qt.rgba(Config.accentColor.r,
                                                   Config.accentColor.g,
                                                   Config.accentColor.b, 0));
                    track.addColorStop(0.5, Qt.rgba(Config.accentColor.r,
                                                   Config.accentColor.g,
                                                   Config.accentColor.b,
                                                   Math.min(0.16, 0.10 * Config.glowIntensity)));
                    track.addColorStop(1.0, Qt.rgba(Config.accentColor.r,
                                                   Config.accentColor.g,
                                                   Config.accentColor.b, 0));
                    ctx.fillStyle = track;
                    ctx.fillRect(0, 0, w, h);

                    // Filled light has no rectangular side boundary. Only its
                    // narrow center is dense; both sides dissolve to alpha 0.
                    const body = ctx.createLinearGradient(0, 0, w, 0);
                    body.addColorStop(0.0, Qt.rgba(Config.accentColor.r,
                                                  Config.accentColor.g,
                                                  Config.accentColor.b, 0));
                    body.addColorStop(0.34, Qt.rgba(Config.accentColor.r,
                                                   Config.accentColor.g,
                                                   Config.accentColor.b,
                                                   Math.min(0.22, 0.14 * Config.glowIntensity)));
                    body.addColorStop(0.5, Qt.rgba(Config.accentColor.r,
                                                  Config.accentColor.g,
                                                  Config.accentColor.b,
                                                  Math.min(0.52, 0.34 * Config.glowIntensity)));
                    body.addColorStop(0.66, Qt.rgba(Config.accentColor.r,
                                                   Config.accentColor.g,
                                                   Config.accentColor.b,
                                                   Math.min(0.22, 0.14 * Config.glowIntensity)));
                    body.addColorStop(1.0, Qt.rgba(Config.accentColor.r,
                                                  Config.accentColor.g,
                                                  Config.accentColor.b, 0));
                    ctx.fillStyle = body;
                    ctx.fillRect(0, Math.min(h, top + 4), w,
                                 Math.max(0, fillHeight - 4));

                    // A small diffuse crest indicates the current level
                    // without becoming a knob or a solid cap.
                    const crest = ctx.createRadialGradient(center, top + 3, 0,
                                                            center, top + 3, 11);
                    crest.addColorStop(0.0, Qt.rgba(Config.accentColor.r,
                                                    Config.accentColor.g,
                                                    Config.accentColor.b,
                                                    Math.min(0.62, 0.40 * Config.glowIntensity)));
                    crest.addColorStop(1.0, Qt.rgba(Config.accentColor.r,
                                                    Config.accentColor.g,
                                                    Config.accentColor.b, 0));
                    ctx.fillStyle = crest;
                    ctx.fillRect(center - 11, top - 8, 22, 22);
                }

                Connections {
                    target: root
                    function onDisplayedAudioVolumeChanged() { volumeGlow.requestPaint(); }
                }
                Connections {
                    target: Config
                    function onAccentColorChanged() { volumeGlow.requestPaint(); }
                    function onGlowIntensityChanged() { volumeGlow.requestPaint(); }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                radius: 1
                color: Config.ringTrackActiveColor
                opacity: 0.68
            }

            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                width: 2
                height: Math.max(2, parent.height * root.displayedAudioVolume)
                radius: 1
                color: Config.brightTextColor
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.SizeVerCursor

                function apply(pointerY) {
                    const local = mapToItem(gauge, 0, pointerY).y;
                    root.audioVolumeRequested(1 - Math.max(0, Math.min(gauge.height, local)) / gauge.height);
                }

                onPressed: mouse => apply(mouse.y)
                onPositionChanged: mouse => { if (pressed) apply(mouse.y); }
            }
        }

    }

    Item {
        anchors.fill: parent
        visible: root.moduleName === "battery"

        Text {
            id: batteryValue
            x: 32
            y: 45
            text: Math.round(root.batteryLevel * 100) + "%"
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 22; weight: Font.DemiBold }
        }
        Text {
            id: batteryStateLabel
            x: 34
            y: 80
            text: root.batteryStateText()
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 14; weight: Font.DemiBold }
        }
        Text {
            id: batteryTimeLabel
            x: 34
            y: 110
            visible: text.length > 0
            text: root.batteryTimeText()
            opacity: 0.96
            color: Config.brightTextColor
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 12; weight: Font.Medium }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleName === "calendar"

        Text {
            x: 32
            y: 25
            text: root.daijiFixed(root.currentDate.getFullYear(), 4) + "年・"
                + root.traditionalMonthNames[root.currentDate.getMonth()]
            color: Config.brightTextColor
            opacity: 0.96
            style: Text.Outline
            styleColor: Config.accentColor
            font { family: Config.resolvedFontFamily; pixelSize: 17; weight: Font.DemiBold }
        }

        Grid {
            x: 32
            y: 62
            columns: 7
            columnSpacing: 0
            rowSpacing: 2

            Repeater {
                model: ["日", "月", "火", "水", "木", "金", "土"]

                Text {
                    required property string modelData
                    width: 28
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Config.workspaceIdleColor
                    opacity: 0.82
                    style: Text.Outline
                    styleColor: Config.accentColor
                    font { family: Config.resolvedFontFamily; pixelSize: 10; weight: Font.Medium }
                }
            }

            Repeater {
                model: root.calendarCells

                Item {
                    required property var modelData
                    width: 28
                    height: 22

                    Canvas {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        visible: parent.modelData.today
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const halo = ctx.createRadialGradient(width / 2, height / 2, 0,
                                                                  width / 2, height / 2, width / 2);
                            halo.addColorStop(0.0, Qt.rgba(Config.accentColor.r,
                                                           Config.accentColor.g,
                                                           Config.accentColor.b, 0.52));
                            halo.addColorStop(1.0, Qt.rgba(Config.accentColor.r,
                                                           Config.accentColor.g,
                                                           Config.accentColor.b, 0));
                            ctx.fillStyle = halo;
                            ctx.fillRect(0, 0, width, height);
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.day
                        color: parent.modelData.today ? Config.brightTextColor
                             : parent.modelData.currentMonth ? Config.brightTextColor
                                                             : Config.workspaceIdleColor
                        opacity: parent.modelData.today ? 1.0
                               : parent.modelData.currentMonth ? 0.88 : 0.34
                        style: parent.modelData.currentMonth ? Text.Outline : Text.Normal
                        styleColor: Config.accentColor
                        font {
                            family: Config.resolvedFontFamily
                            pixelSize: 11
                            weight: parent.modelData.today ? Font.DemiBold : Font.Medium
                        }
                    }
                }
            }
        }
    }
    }
}
