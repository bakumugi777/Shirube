pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string configRoot: Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")
    readonly property string configPath: Quickshell.env("SHIRUBE_CONFIG_FILE")
        || (configRoot + "/shirube/config.json")
    readonly property string matugenPath: Quickshell.env("SHIRUBE_MATUGEN_FILE")
        || (configRoot + "/shirube/matugen-colors.json")
    property var data: ({})
    property var matugenData: ({})

    function read(group, key, fallback) {
        const section = data[group];
        return section !== undefined && section[key] !== undefined
             ? section[key]
             : fallback;
    }

    function load() {
        try {
            const parsed = JSON.parse(file.text());
            data = parsed && typeof parsed === "object" ? parsed : {};
        } catch (error) {
            console.warn("Shirube: invalid config.json, using defaults:", error);
            data = {};
        }
    }

    function loadMatugen() {
        try {
            const parsed = JSON.parse(matugenFile.text());
            if (parsed && typeof parsed === "object"
                    && validGeneratedColor(parsed.accent)
                    && validGeneratedColor(parsed.text)
                    && validGeneratedColor(parsed.surface)) {
                matugenData = parsed;
            } else {
                matugenData = {};
            }
        } catch (error) {
            matugenData = {};
        }
    }

    function validGeneratedColor(value) {
        return typeof value === "string"
            && /^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value);
    }

    function mixColor(a, b, amount) {
        const t = Math.max(0, Math.min(1, amount));
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function visibleAccent(color) {
        const hue = color.hslHue >= 0 ? color.hslHue : 0.57;
        return Qt.hsla(hue,
                       Math.max(0.46, color.hslSaturation),
                       Math.max(0.58, Math.min(0.78, color.hslLightness)), 1.0);
    }

    function paletteColor(key, defaultColor, generatedColor) {
        const colors = data.colors || {};
        const overrides = colors.overrides || {};
        if (overrides[key] !== undefined)
            return overrides[key];
        if (matugenAvailable)
            return generatedColor;
        return colors[key] !== undefined ? colors[key] : defaultColor;
    }

    readonly property string primaryFont: read("font", "family", "Makinas")
    readonly property var fontFamilies: {
        const fallbacks = read("font", "fallbacks", ["Noto Sans CJK JP", "sans-serif"]);
        return [primaryFont].concat(Array.isArray(fallbacks) ? fallbacks : []);
    }
    readonly property string resolvedFontFamily: {
        const installed = Qt.fontFamilies();
        for (let i = 0; i < fontFamilies.length; ++i) {
            const wanted = String(fontFamilies[i]);
            for (let j = 0; j < installed.length; ++j) {
                if (String(installed[j]).toLowerCase() === wanted.toLowerCase())
                    return installed[j];
            }
        }
        return "sans-serif";
    }
    readonly property int moduleFontSize: read("font", "moduleSize", 14)
    readonly property int workspaceFontSize: read("font", "workspaceSize", 14)
    readonly property int clockFontSize: read("font", "clockSize", 16)
    readonly property int fontWeight: read("font", "weight", 500)
    readonly property real letterSpacing: read("font", "letterSpacing", 1.5)

    readonly property bool matugenAvailable:
        validGeneratedColor(matugenData.accent)
        && validGeneratedColor(matugenData.text)
        && validGeneratedColor(matugenData.surface)
    onMatugenAvailableChanged: console.info("Shirube palette:",
        matugenAvailable ? "matugen" : "default")
    // JSON values are JavaScript strings. Convert the accent to QML's color
    // type before reading its HSL components; reading hsl* from the raw string
    // yields NaN and can turn the generated palette transparent or black.
    readonly property color rawGeneratedAccent:
        matugenData.accent !== undefined ? matugenData.accent : "#9acbfa"
    readonly property color generatedAccent: visibleAccent(rawGeneratedAccent)
    readonly property color generatedText:
        matugenData.text !== undefined ? matugenData.text : "#e0e2e8"
    readonly property color generatedSurface:
        matugenData.surface !== undefined ? matugenData.surface : "#142631"
    readonly property color whitePoint: "#ffffff"

    property color accentColor: paletteColor("accent", "#9acbfa", generatedAccent)
    property color textColor: paletteColor("text", "#e0e2e8", mixColor(generatedText, whitePoint, 0.08))
    property color subduedTextColor: paletteColor("subduedText", "#92a6b7", mixColor(generatedText, generatedAccent, 0.28))
    property color brightTextColor: paletteColor("brightText", "#ffffff", mixColor(generatedText, whitePoint, 0.48))
    property color captionColor: paletteColor("caption", "#91b3bd", mixColor(generatedText, generatedAccent, 0.44))
    property color workspaceActiveColor: paletteColor("workspaceActive", "#edf8fa", mixColor(generatedAccent, whitePoint, 0.62))
    property color workspaceIdleColor: paletteColor("workspaceIdle", "#aac4ca", mixColor(generatedText, generatedAccent, 0.42))
    property color clockColor: paletteColor("clock", "#d4e5e8", mixColor(generatedText, generatedAccent, 0.18))
    property color clockSeparatorColor: paletteColor("clockSeparator", "#b8d0d5", mixColor(generatedText, generatedAccent, 0.32))
    property color ringTrackColor: paletteColor("ringTrack", "#343f5962", withAlpha(generatedAccent, 0.20))
    property color ringTrackActiveColor: paletteColor("ringTrackActive", "#6b789fab", withAlpha(mixColor(generatedAccent, whitePoint, 0.18), 0.42))
    property color ringInnerColor: paletteColor("ringInner", "#304b7182", withAlpha(generatedAccent, 0.28))
    property color lightNearColor: paletteColor("lightNear", "#78bfff", mixColor(generatedAccent, whitePoint, 0.30))
    property color lightInnerColor: paletteColor("lightInner", "#62afff", mixColor(generatedAccent, whitePoint, 0.14))
    property color lightMidColor: paletteColor("lightMid", "#4d9ce8", generatedAccent)
    property color lightOuterColor: paletteColor("lightOuter", "#3c87d2", Qt.darker(generatedAccent, 1.18))
    property color lightFarColor: paletteColor("lightFar", "#2d72b8", Qt.darker(generatedAccent, 1.38))
    property color lightSourceColor: paletteColor("lightSource", "#add8ff", mixColor(generatedAccent, whitePoint, 0.42))
    property color hologramPanelColor: paletteColor("hologramPanel", "#142631", generatedSurface)
    readonly property int paletteTransitionMs: Math.max(0, Math.min(3000,
        read("appearance", "paletteTransitionMs", 650)))

    Behavior on accentColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on textColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on subduedTextColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on brightTextColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on captionColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on workspaceActiveColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on workspaceIdleColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on clockColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on clockSeparatorColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on ringTrackColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on ringTrackActiveColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on ringInnerColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on lightNearColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on lightInnerColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on lightMidColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on lightOuterColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on lightFarColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on lightSourceColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }
    Behavior on hologramPanelColor { ColorAnimation { duration: root.animationsEnabled ? root.paletteTransitionMs : 0; easing.type: Easing.InOutSine } }

    // Keep the compositor reservation independent from the visual light width.
    // The dedicated key also lets existing configs that still contain the old
    // reservedWidth value adopt the new default instead of remaining at 48px.
    readonly property int exclusiveZoneWidth: read("layout", "exclusiveZoneWidth", 64)
    readonly property int compactSurfaceWidth: read("layout", "compactSurfaceWidth", 90)
    readonly property int lightWidth: read("layout", "lightWidth", compactSurfaceWidth)
    readonly property int expandedSurfaceWidth: Math.max(compactSurfaceWidth,
        read("layout", "expandedSurfaceWidth", 380))
    readonly property real moduleAxis: read("layout", "moduleAxis", 26)
    readonly property var middleActions: {
        const fallback = [
            { symbol: "☯", name: "Launcher", command: [] },
            { symbol: "終", name: "Session", command: [] }
        ];
        const actions = read("middle", "actions", fallback);
        return Array.isArray(actions) ? actions : fallback;
    }
    readonly property int middleActionSpacing: Math.max(0,
        read("middle", "spacing", 6))
    readonly property bool animationsEnabled:
        read("animation", "enabled", true)
    readonly property int interactionAnimationMs: animationsEnabled
        ? Math.max(0, read("animation", "interactionMs", 280)) : 0
    readonly property int startupLightMs: animationsEnabled
        ? Math.max(0, read("animation", "startupLightMs", 720)) : 0
    readonly property int startupUiDelayMs: animationsEnabled
        ? Math.max(0, read("animation", "startupUiDelayMs", 260)) : 0
    readonly property int startupUiMs: animationsEnabled
        ? Math.max(0, read("animation", "startupUiMs", 520)) : 0
    readonly property real idleOpacity: read("appearance", "idleOpacity", 1.0)
    readonly property real subduedOpacity: read("appearance", "subduedOpacity", 0.50)
    readonly property real hoverOpacity: read("appearance", "hoverOpacity", 1.0)
    readonly property real hologramPanelOpacity: Math.max(0, Math.min(0.3,
        read("appearance", "hologramPanelOpacity", 0.12)))
    readonly property real lightUnderlayOpacity: Math.max(0, Math.min(1.0,
        read("appearance", "lightUnderlayOpacity", 0.16)))
    readonly property real glowIntensity: Math.max(0.25, Math.min(2.0,
        read("appearance", "glowIntensity", 1.4)))
    readonly property real textGlowIntensity: Math.max(0, Math.min(2.0,
        read("appearance", "textGlowIntensity", 1.0)))
    readonly property int ringTransitionMs: animationsEnabled
        ? Math.max(0, Math.min(2000,
            read("appearance", "ringTransitionMs", 520))) : 0
    readonly property int audioGaugeTransitionMs: animationsEnabled
        ? Math.max(0, Math.min(600,
            read("appearance", "audioGaugeTransitionMs", 160))) : 0
    readonly property bool floatingEnabled:
        read("appearance", "floatingEnabled", true)
    readonly property bool ambientAnimationEnabled:
        read("appearance", "ambientAnimationEnabled", true)
    readonly property real floatingAmplitude: Math.max(0, Math.min(3,
        read("appearance", "floatingAmplitude", 1.1)))
    readonly property int floatingPeriodMs: Math.max(3000,
        read("appearance", "floatingPeriodMs", 7200))
    readonly property bool lightWaveEnabled:
        read("appearance", "lightWaveEnabled", true)
    readonly property real lightWaveAmplitude: Math.max(0, Math.min(8,
        read("appearance", "lightWaveAmplitude", 8.0)))
    readonly property int lightWavePeriodMs: Math.max(2000,
        read("appearance", "lightWavePeriodMs", 3000))
    readonly property int lightWaveFps: Math.max(8, Math.min(30,
        read("appearance", "lightWaveFps", 10)))
    readonly property int lightFieldStripHeight: Math.max(1, Math.min(6,
        read("appearance", "lightFieldStripHeight", 5)))
    readonly property bool audioReactionEnabled:
        read("appearance", "audioReactionEnabled", true)
    readonly property real audioReactionStrength: Math.max(0, Math.min(1.5,
        read("appearance", "audioReactionStrength", 0.90)))
    readonly property int audioReactionSmoothingMs: Math.max(100, Math.min(1200,
        read("appearance", "audioReactionSmoothingMs", 360)))
    readonly property int audioReactionAttackMs: Math.max(60, Math.min(600,
        read("appearance", "audioReactionAttackMs", 90)))
    readonly property int audioReactionReleaseMs: Math.max(120, Math.min(1600,
        read("appearance", "audioReactionReleaseMs", 380)))
    readonly property real audioReactionBrightness: Math.max(0, Math.min(2.5,
        read("appearance", "audioReactionBrightness", 1.35)))
    readonly property int systemUpdateMs: Math.max(500, read("updates", "systemMs", 2000))
    readonly property int desktopUpdateMs: Math.max(500, read("updates", "desktopMs", 3000))
    readonly property int audioUpdateMs: Math.max(500,
        read("updates", "audioMs", desktopUpdateMs))
    readonly property int networkUpdateMs: Math.max(1000,
        read("updates", "networkMs", 6000))
    readonly property int batteryUpdateMs: Math.max(2000,
        read("updates", "batteryMs", 15000))
    readonly property int workspaceFallbackMs: Math.max(500, read("updates", "workspaceFallbackMs", 2000))

    property FileView file: FileView {
        path: root.configPath
        blockLoading: true
        watchChanges: true
        onLoaded: root.load()
        onFileChanged: reload()
    }

    // Generated independently so Matugen never overwrites behavioral config.
    property FileView matugenFile: FileView {
        path: root.matugenPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadMatugen()
        onFileChanged: reload()
        onLoadFailed: root.matugenData = ({})
    }

    property Timer matugenProbeTimer: Timer {
        interval: 5000
        repeat: true
        running: !root.matugenAvailable
        onTriggered: matugenFile.reload()
    }
}
