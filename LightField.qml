import QtQuick

Item {
    id: root

    property real baseWidth: 78
    property bool expanded: expansion > 0.001
    property real influenceCenterY: height / 2
    property real influenceWidth: baseWidth
    property real influenceHeight: 180
    property int morphDuration: Config.interactionAnimationMs
    property bool transitioning: false
    property real transitionProgress: 1
    property real previousCenterY: influenceCenterY
    property real previousWidth: baseWidth
    property real previousHeight: influenceHeight
    property real wavePhase: 0
    property real audioLevel: 0
    property real reveal: 1

    property real expansion: 0
    property real animatedCenterY: influenceCenterY
    property real animatedWidth: influenceWidth
    property real animatedHeight: influenceHeight

    Behavior on animatedCenterY {
        enabled: root.expanded
        NumberAnimation { duration: root.morphDuration; easing.type: Easing.InOutCubic }
    }
    Behavior on animatedWidth {
        enabled: root.expanded
        NumberAnimation { duration: root.morphDuration; easing.type: Easing.InOutCubic }
    }
    Behavior on animatedHeight {
        enabled: root.expanded
        NumberAnimation { duration: root.morphDuration; easing.type: Easing.InOutCubic }
    }

    // A painted field gives the falloff a light-like curve instead of making
    // the shell look like a translucent rectangular panel.
    Canvas {
        id: field
        anchors.fill: parent
        // Let the scene graph schedule this continuous raster work without
        // blocking input handling in one long immediate paint operation.
        // Threaded mode cannot safely create these dynamic gradients on every
        // supported Qt backend, so Cooperative is the portable choice here.
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            // Draw one continuous field. Expansion changes the horizontal
            // decay distance of this same edge light at each y coordinate;
            // there is no extra ellipse, panel, or outlined expansion shape.
            const p = root.expansion;
            // Five-pixel scan bands remain visually continuous for this slow
            // field while substantially reducing per-frame gradient creation.
            const stripHeight = Config.lightFieldStripHeight || 5;
            const glow = Config.glowIntensity;
            const reactionStrength = Number.isFinite(Config.audioReactionStrength)
                                   ? Config.audioReactionStrength : 0.75;
            // Interaction has the highest visual priority. Keep a trace of
            // media response during expansion, but do not let it compete with
            // the selected module's field deformation.
            const interactionDamping = 1 - 0.58 * p;
            const audioBend = Config.animationsEnabled === true
                           && Config.audioReactionEnabled === true
                            ? Math.max(0, Math.min(1, root.audioLevel))
                              * reactionStrength * interactionDamping
                            : 0;
            const reactionBrightness = Number.isFinite(Config.audioReactionBrightness)
                                     ? Config.audioReactionBrightness : 1.35;
            const audioLight = Math.min(1.5, audioBend * reactionBrightness);
            const ambientPulse = Config.animationsEnabled === true
                              && Config.ambientAnimationEnabled === true
                               ? (0.5 + 0.5 * Math.sin(root.wavePhase * 0.5))
                                 * 0.014 * (1 - 0.72 * p)
                               : 0;

            for (let y = 0; y < height; y += stripHeight) {
                const sampleY = y + stripHeight * 0.5;
                // A Gaussian has neither a plateau nor a finite cutoff. Its
                // slope is zero at the center and it approaches the idle field
                // asymptotically, so the silhouette has no shoulder or cliff.
                let influence;
                let fieldWidth;
                if (root.transitioning) {
                    const t = root.transitionProgress;
                    const oldSigma = Math.max(72, root.previousHeight * 0.62);
                    const newSigma = Math.max(72, root.influenceHeight * 0.62);
                    const oldN = (sampleY - root.previousCenterY) / oldSigma;
                    const newN = (sampleY - root.influenceCenterY) / newSigma;
                    const oldField = Math.exp(-0.5 * oldN * oldN);
                    const newField = Math.exp(-0.5 * newN * newN);
                    const oldWeight = 1 - t;
                    const newWeight = t;

                    // The weights always sum to one. Where the fields overlap,
                    // brightness is preserved without additive overexposure;
                    // elsewhere the old field contracts as the new one grows.
                    influence = p * (oldWeight * oldField + newWeight * newField);
                    const oldExtra = p * oldWeight
                                   * Math.max(0, root.previousWidth - root.baseWidth)
                                   * oldField;
                    const newExtra = p * newWeight
                                   * Math.max(0, root.influenceWidth - root.baseWidth)
                                   * newField;
                    // Do not average the two silhouettes into a travelling
                    // hill. Each field changes its own reach independently.
                    // Only genuine spatial overlap contributes part of the
                    // smaller reach, preserving the shared light without
                    // letting distant Gaussian tails drag the whole shape.
                    const overlap = Math.sqrt(oldField * newField);
                    fieldWidth = root.baseWidth + Math.max(oldExtra, newExtra)
                               + Math.min(oldExtra, newExtra) * overlap;
                } else {
                    const sigma = Math.max(72, root.animatedHeight * 0.62);
                    const normalized = (sampleY - root.animatedCenterY) / sigma;
                    const verticalFalloff = Math.exp(-0.5 * normalized * normalized);
                    influence = p * verticalFalloff;
                    fieldWidth = root.baseWidth
                               + (root.animatedWidth - root.baseWidth) * influence;
                }
                // The source remains rigidly attached to the left edge. Only
                // the decay distance breathes, producing a slow non-uniform
                // wave at the field's transparent right boundary.
                if (Config.animationsEnabled === true
                        && Config.ambientAnimationEnabled === true
                        && Config.lightWaveEnabled && Config.lightWaveAmplitude > 0) {
                    const spatialA = sampleY / 54 + root.wavePhase;
                    const spatialB = sampleY / 101 - root.wavePhase * 0.63;
                    const wave = Config.lightWaveAmplitude
                               * (1 + 0.48 * audioBend)
                               * (0.68 * Math.sin(spatialA)
                                + 0.32 * Math.sin(spatialB))
                               * (1 + 0.28 * influence);
                    fieldWidth = Math.max(1, Math.min(width, fieldWidth + wave));
                }
                // Audio changes the material of the existing field rather
                // than drawing a meter. A broad, slowly varying bend avoids a
                // spectrum-analyzer silhouette even on sharp transients.
                if (audioBend > 0) {
                    const audioCurve = 8.0 + 2.8 * Math.sin(sampleY / 146
                                                    + root.wavePhase * 0.24);
                    fieldWidth = Math.max(1, Math.min(width,
                        fieldWidth + audioBend * audioCurve));
                }
                // Startup reveals the existing field from its physical source.
                // Scaling the decay distance keeps the left edge fixed and
                // avoids introducing a temporary overlay shape.
                fieldWidth = Math.max(1, fieldWidth * root.reveal);
                // Expansion increases local density as well as reach. This is
                // still the same field; no panel-shaped light is added.
                const sourceLift = 0.060 * influence + 0.105 * audioLight;
                const audioInnerLift = 0.092 * audioLight;
                const audioMidLift = 0.108 * audioLight;
                const audioOuterLift = 0.094 * audioLight;
                const audioFarLift = 0.062 * audioLight;

                // This contrast component uses the light field's own changing
                // silhouette. It has no independent panel edge and reaches
                // alpha zero at exactly the same moving right boundary.
                const underlayAlpha = Config.lightUnderlayOpacity * root.reveal;
                if (underlayAlpha > 0.001) {
                    const underlay = ctx.createLinearGradient(0, 0, fieldWidth, 0);
                    underlay.addColorStop(0.00, Qt.rgba(0, 0, 0, underlayAlpha));
                    underlay.addColorStop(0.34, Qt.rgba(0, 0, 0, underlayAlpha * 0.58));
                    underlay.addColorStop(0.68, Qt.rgba(0, 0, 0, underlayAlpha * 0.16));
                    underlay.addColorStop(1.00, Qt.rgba(0, 0, 0, 0));
                    ctx.fillStyle = underlay;
                    ctx.fillRect(0, y, fieldWidth, stripHeight + 0.5);
                }

                const ambient = ctx.createLinearGradient(0, 0, fieldWidth, 0);
                ambient.addColorStop(0.00, Qt.rgba(Config.lightNearColor.r, Config.lightNearColor.g, Config.lightNearColor.b, (0.34 + sourceLift + ambientPulse) * glow));
                ambient.addColorStop(0.20, Qt.rgba(Config.lightInnerColor.r, Config.lightInnerColor.g, Config.lightInnerColor.b, (0.275 + 0.050 * influence + audioInnerLift + ambientPulse * 0.86) * glow));
                ambient.addColorStop(0.44, Qt.rgba(Config.lightMidColor.r, Config.lightMidColor.g, Config.lightMidColor.b, (0.195 + 0.070 * influence + audioMidLift + ambientPulse * 0.58) * glow));
                ambient.addColorStop(0.66, Qt.rgba(Config.lightOuterColor.r, Config.lightOuterColor.g, Config.lightOuterColor.b, (0.105 + 0.150 * influence + audioOuterLift) * glow));
                ambient.addColorStop(0.82, Qt.rgba(Config.lightFarColor.r, Config.lightFarColor.g, Config.lightFarColor.b, (0.034 + 0.185 * influence + audioFarLift) * glow));
                ambient.addColorStop(0.92, Qt.rgba(Config.lightFarColor.r, Config.lightFarColor.g, Config.lightFarColor.b, (0.008 + 0.075 * influence + 0.026 * audioLight) * glow));
                ambient.addColorStop(1.00, Qt.rgba(Config.lightFarColor.r, Config.lightFarColor.g, Config.lightFarColor.b, 0.0));
                ctx.fillStyle = ambient;
                ctx.fillRect(0, y, fieldWidth, stripHeight + 0.5);
            }

        }

        Connections {
            target: root
            function onExpansionChanged() { field.requestPaint(); }
            function onAnimatedCenterYChanged() { field.requestPaint(); }
            function onAnimatedWidthChanged() { field.requestPaint(); }
            function onAnimatedHeightChanged() { field.requestPaint(); }
            function onBaseWidthChanged() { field.requestPaint(); }
            function onTransitioningChanged() { field.requestPaint(); }
            function onTransitionProgressChanged() { field.requestPaint(); }
            function onPreviousCenterYChanged() { field.requestPaint(); }
            function onPreviousWidthChanged() { field.requestPaint(); }
            function onPreviousHeightChanged() { field.requestPaint(); }
            function onInfluenceCenterYChanged() { field.requestPaint(); }
            function onInfluenceWidthChanged() { field.requestPaint(); }
            function onInfluenceHeightChanged() { field.requestPaint(); }
            function onAudioLevelChanged() { field.requestPaint(); }
            function onRevealChanged() { field.requestPaint(); }
        }
        Connections {
            target: Config
            function onLightNearColorChanged() { field.requestPaint(); }
            function onLightInnerColorChanged() { field.requestPaint(); }
            function onLightMidColorChanged() { field.requestPaint(); }
            function onLightOuterColorChanged() { field.requestPaint(); }
            function onLightFarColorChanged() { field.requestPaint(); }
            function onGlowIntensityChanged() { field.requestPaint(); }
            function onAnimationsEnabledChanged() { field.requestPaint(); }
            function onAmbientAnimationEnabledChanged() { field.requestPaint(); }
            function onAudioReactionEnabledChanged() { field.requestPaint(); }
            function onAudioReactionBrightnessChanged() { field.requestPaint(); }
            function onAudioReactionStrengthChanged() { field.requestPaint(); }
            function onLightWaveEnabledChanged() { field.requestPaint(); }
            function onLightWaveAmplitudeChanged() { field.requestPaint(); }
            function onLightUnderlayOpacityChanged() { field.requestPaint(); }
        }
    }

    Timer {
        id: waveTimer
        interval: Math.max(33, Math.round(1000 / Config.lightWaveFps))
        repeat: true
        running: root.visible && Config.animationsEnabled === true
              && Config.ambientAnimationEnabled === true
              && Config.lightWaveEnabled
              && Config.lightWaveAmplitude > 0
        onTriggered: {
            // Keep phase continuous. Wrapping at 2π is only seamless for the
            // primary wave; the secondary 0.63× phase would jump there.
            root.wavePhase += Math.PI * 2 * interval
                            / Config.lightWavePeriodMs;
            field.requestPaint();
        }
    }

    // The physical edge is the source of the field, not a separate bar body.
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 1
        color: Config.lightSourceColor
        opacity: root.reveal * Math.min(1.0, 0.91 * Config.glowIntensity)
    }
}
