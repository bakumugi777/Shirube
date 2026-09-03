import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    signal ipcRequested(string action, string moduleName)

    IpcHandler {
        target: "shirube"

        function toggle(module: string): string {
            root.ipcRequested("toggle", module);
            return "ok";
        }

        function open(module: string): string {
            root.ipcRequested("open", module);
            return "ok";
        }

        function close(): string {
            root.ipcRequested("close", "");
            return "ok";
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    SystemStatus {
        id: status
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panel
            required property ShellScreen modelData
            readonly property real moduleAxis: Config.moduleAxis
            readonly property real detailAxis: Config.moduleAxis + 14
            property string expandedModule: ""
            property real detailY: 0
            property real detailHeight: 154
            property real detailContentReach: 248
            property real detailTetherY: 77
            property bool detailPresented: false
            property bool detailClosing: false
            property real detailOpacity: 0
            property real fieldExpansion: 0
            property string pendingModule: ""
            property var pendingSourceItem: null
            property string outgoingModule: ""
            property real outgoingY: 0
            property real outgoingTetherY: 77
            property bool outgoingPresented: false
            property real outgoingOpacity: 0
            property bool detailSwitching: false
            property real lightTransitionProgress: 1
            property real previousLightCenterY: 0
            property real previousLightWidth: Config.lightWidth
            property real previousLightHeight: 180
            property real startupLightReveal: Config.animationsEnabled ? 0 : 1
            property real startupUiReveal: Config.animationsEnabled ? 0 : 1

            Component.onCompleted: {
                if (Config.animationsEnabled)
                    startupTransition.restart();
            }

            ParallelAnimation {
                id: startupTransition

                NumberAnimation {
                    target: panel
                    property: "startupLightReveal"
                    from: 0
                    to: 1
                    duration: Config.startupLightMs
                    easing.type: Easing.OutCubic
                }

                SequentialAnimation {
                    PauseAnimation { duration: Config.startupUiDelayMs }
                    NumberAnimation {
                        target: panel
                        property: "startupUiReveal"
                        from: 0
                        to: 1
                        duration: Config.startupUiMs
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Connections {
                target: Config
                function onAnimationsEnabledChanged() {
                    if (!Config.animationsEnabled) {
                        startupTransition.stop();
                        panel.startupLightReveal = 1;
                        panel.startupUiReveal = 1;
                    }
                }
            }

            function lightWidthFor(contentReach) {
                const adaptiveMargin = Math.max(40, contentReach * 0.22);
                return Math.min(width,
                    detailAxis + contentReach + adaptiveMargin);
            }

            function lightHeightFor(contentHeight) {
                const adaptiveMargin = Math.max(54, contentHeight * 0.28);
                return contentHeight + adaptiveMargin;
            }

            function moduleGlowFor(name) {
                if (detailSwitching) {
                    if (expandedModule === name)
                        return lightTransitionProgress;
                    if (outgoingModule === name)
                        return 1 - lightTransitionProgress;
                    return 0;
                }
                return expandedModule === name ? fieldExpansion : 0;
            }

            function closeDetail() {
                autoCloseTimer.stop();
                pendingModule = "";
                pendingSourceItem = null;
                beginClose();
            }

            function sourceForModule(name) {
                if (name === "cpu")
                    return cpuModule;
                if (name === "memory")
                    return memoryModule;
                if (name === "audio")
                    return audioModule;
                if (name === "network")
                    return networkModule;
                if (name === "battery" && status.batteryPresent)
                    return batteryModule;
                if (name === "calendar")
                    return clockModule;
                return null;
            }

            function handleIpcRequest(action, name) {
                if (action === "close") {
                    closeDetail();
                    return;
                }

                const sourceItem = sourceForModule(name);
                if (sourceItem === null)
                    return;

                if (action === "toggle") {
                    toggleDetail(name, sourceItem);
                    return;
                }

                if (action === "open") {
                    if (detailClosing) {
                        pendingModule = name;
                        pendingSourceItem = sourceItem;
                    } else if (expandedModule === name) {
                        return;
                    } else if (expandedModule.length > 0) {
                        switchDetail(name, sourceItem);
                    } else {
                        openDetail(name, sourceItem);
                    }
                }
            }

            function expandedSourceHovered() {
                return expandedModule === "cpu" ? cpuModule.hovered
                     : expandedModule === "memory" ? memoryModule.hovered
                     : expandedModule === "audio" ? audioModule.hovered
                     : expandedModule === "network" ? networkModule.hovered
                     : expandedModule === "battery" ? batteryModule.hovered
                     : expandedModule === "calendar" ? clockModule.hovered
                     : false;
            }

            function scheduleAutoClose() {
                if (expandedModule.length === 0 || detailClosing || detailSwitching) {
                    autoCloseTimer.stop();
                    return;
                }
                if (expandedSourceHovered() || detailOverlay.hovered)
                    autoCloseTimer.stop();
                else
                    autoCloseTimer.restart();
            }

            function beginClose() {
                if (expandedModule.length === 0 || detailClosing)
                    return;
                detailClosing = true;
                detailSwitching = false;
                switchTransition.stop();
                outgoingPresented = false;
                outgoingModule = "";
                openTransition.stop();
                closeTransition.restart();
            }

            function toggleDetail(name, sourceItem) {
                if (detailClosing) {
                    pendingModule = name;
                    pendingSourceItem = sourceItem;
                    return;
                }
                if (expandedModule === name) {
                    closeDetail();
                    return;
                }
                if (expandedModule.length > 0) {
                    switchDetail(name, sourceItem);
                    return;
                }
                openDetail(name, sourceItem);
            }

            function switchDetail(name, sourceItem) {
                autoCloseTimer.stop();
                switchTransition.stop();
                detailSwitching = true;
                previousLightCenterY = detailY + detailHeight / 2;
                previousLightWidth = lightWidthFor(detailContentReach);
                previousLightHeight = lightHeightFor(detailHeight);
                lightTransitionProgress = 0;

                // Both projections are Items on the same scene, so the old
                // and new states are committed in one frame and can crossfade
                // without a native-window mapping delay.
                outgoingModule = expandedModule;
                outgoingY = detailY;
                outgoingTetherY = detailTetherY;
                outgoingOpacity = detailOpacity;
                outgoingPresented = true;

                detailPresented = false;
                detailOpacity = 0;
                const wantedHeight = detailOverlay.heightForModule(name);
                detailContentReach = detailOverlay.contentReachForModule(name);
                detailHeight = wantedHeight;
                detailY = Math.max(12, Math.min(height - wantedHeight - 12,
                    sourceItem.y + sourceItem.height / 2 - wantedHeight / 2));
                detailTetherY = Math.max(8, Math.min(wantedHeight - 8,
                    sourceItem.y + sourceItem.height / 2 - detailY));
                expandedModule = name;
                detailPresented = true;

                // fieldExpansion remains at one. Updating these target
                // dimensions makes LightField morph directly between the two
                // expanded shapes while both contents crossfade.
                switchTransition.restart();
            }

            function openDetail(name, sourceItem) {
                autoCloseTimer.stop();
                closeTransition.stop();
                openTransition.stop();
                switchTransition.stop();
                outgoingPresented = false;
                outgoingModule = "";
                detailPresented = false;
                detailClosing = false;
                detailSwitching = false;
                detailOpacity = 0;
                fieldExpansion = 0;
                const wantedHeight = detailOverlay.heightForModule(name);
                detailContentReach = detailOverlay.contentReachForModule(name);
                detailHeight = wantedHeight;
                detailY = Math.max(12, Math.min(height - wantedHeight - 12,
                    sourceItem.y + sourceItem.height / 2 - wantedHeight / 2));
                detailTetherY = Math.max(8, Math.min(wantedHeight - 8,
                    sourceItem.y + sourceItem.height / 2 - detailY));
                expandedModule = name;
                detailPresented = true;
                openTransition.restart();
            }

            ParallelAnimation {
                id: openTransition
                NumberAnimation {
                    target: panel
                    property: "fieldExpansion"
                    from: 0
                    to: 1
                    duration: Config.interactionAnimationMs
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panel
                    property: "detailOpacity"
                    from: 0
                    to: 1
                    duration: Config.interactionAnimationMs
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: closeTransition
                NumberAnimation {
                    target: panel
                    property: "fieldExpansion"
                    to: 0
                    duration: Math.round(Config.interactionAnimationMs * 1.55)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panel
                    property: "detailOpacity"
                    to: 0
                    duration: Math.round(Config.interactionAnimationMs * 1.55)
                    easing.type: Easing.OutCubic
                }
                onFinished: {
                    panel.detailPresented = false;
                    panel.expandedModule = "";
                    const nextModule = panel.pendingModule;
                    const nextSource = panel.pendingSourceItem;
                    panel.pendingModule = "";
                    panel.pendingSourceItem = null;
                    panel.detailClosing = false;
                    if (nextModule.length > 0 && nextSource !== null)
                        Qt.callLater(function() {
                            panel.openDetail(nextModule, nextSource);
                        });
                }
            }

            ParallelAnimation {
                id: switchTransition
                NumberAnimation {
                    target: panel
                    property: "lightTransitionProgress"
                    from: 0
                    to: 1
                    duration: Math.round(Config.interactionAnimationMs * 2.0)
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    target: panel
                    property: "outgoingOpacity"
                    to: 0
                    duration: Math.round(Config.interactionAnimationMs * 2.0)
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    target: panel
                    property: "detailOpacity"
                    from: 0
                    to: 1
                    duration: Math.round(Config.interactionAnimationMs * 2.0)
                    easing.type: Easing.InOutCubic
                }
                onFinished: {
                    panel.outgoingPresented = false;
                    panel.outgoingModule = "";
                    panel.detailSwitching = false;
                    panel.scheduleAutoClose();
                }
            }

            Timer {
                id: autoCloseTimer
                interval: 260
                repeat: false
                onTriggered: {
                    if (!panel.expandedSourceHovered() && !detailOverlay.hovered)
                        panel.closeDetail();
                }
            }

            screen: modelData
            // The surface is wider than the visible light so its deformation can
            // be drawn safely. The exclusive zone independently reserves space
            // for Shirube in the compositor's window layout.
            // The visual field never changes native-window size. Normal and
            // expanded states are two shapes of the same light surface.
            // Input remains limited by the mask below.
            implicitWidth: Config.expandedSurfaceWidth
            color: "transparent"
            exclusiveZone: Config.exclusiveZoneWidth
            focusable: false
            aboveWindows: true

            // The fading light is visual only. Input is accepted solely by
            // holographic controls; the rest passes through to applications.
            mask: Region {
                Region { item: workspaceModule }
                Region { item: middleActionList }
                Region { item: cpuModule }
                Region { item: memoryModule }
                Region { item: audioModule }
                Region { item: networkModule }
                Region { item: batteryModule }
                Region { item: clockModule }
                Region { item: detailOverlay }
            }

            anchors {
                top: true
                bottom: true
                left: true
            }

            // Layer 1: light field. It owns no information or input.
            Item {
                id: lightFieldLayer
                anchors.fill: parent

                LightField {
                    id: lightField
                    anchors.fill: parent
                    baseWidth: Config.lightWidth
                    expansion: panel.fieldExpansion
                    influenceCenterY: panel.detailY + panel.detailHeight / 2
                    influenceWidth: panel.lightWidthFor(panel.detailContentReach)
                    influenceHeight: panel.lightHeightFor(panel.detailHeight)
                    morphDuration: panel.detailSwitching
                                 ? Math.round(Config.interactionAnimationMs * 2.0)
                                 : Config.interactionAnimationMs
                    transitioning: panel.detailSwitching
                    transitionProgress: panel.lightTransitionProgress
                    previousCenterY: panel.previousLightCenterY
                    previousWidth: panel.previousLightWidth
                    previousHeight: panel.previousLightHeight
                    audioLevel: status.audioLevel
                    reveal: panel.startupLightReveal
                }
            }

            // Layer 2: normally visible floating holograms.
            Item {
                id: holographicUiLayer
                readonly property real batterySpacing: status.batteryPresent ? 50 : 0
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }
                width: parent.width
                opacity: panel.startupUiReveal
                transform: Translate {
                    x: -4 * (1 - panel.startupUiReveal)
                }

                WorkspaceList {
                    id: workspaceModule
                    x: panel.moduleAxis - width / 2
                    y: 16
                    workspaces: status.workspaces
                    activeWorkspace: status.activeWorkspace
                    onWorkspaceActivated: number => {
                        panel.closeDetail();
                        status.activateWorkspace(number);
                    }
                }

                Column {
                    id: middleActionList
                    width: implicitWidth
                    height: implicitHeight
                    x: panel.moduleAxis - width / 2
                    y: Math.round((parent.height - height) / 2)
                    spacing: Config.middleActionSpacing

                    Repeater {
                        model: Config.middleActions

                        ActionGlyph {
                            required property var modelData
                            action: modelData
                            visible: modelData.enabled !== false
                        }
                    }
                }

                KanjiClock {
                    id: clockModule
                    x: panel.moduleAxis - width / 2
                    y: parent.height - height - 18
                    date: clock.date
                    expanded: panel.expandedModule === "calendar"
                    expansionGlow: panel.moduleGlowFor("calendar")
                    onActivated: panel.toggleDetail("calendar", clockModule)
                }

                StatusRing {
                    id: cpuModule
                    x: panel.moduleAxis - width / 2
                    y: Math.round(clockModule.y - 200
                                  - holographicUiLayer.batterySpacing - height / 2)
                    symbol: "算"
                    value: status.cpuUsage
                    accessibleName: "CPU"
                    expanded: panel.expandedModule === "cpu"
                    expansionGlow: panel.moduleGlowFor("cpu")
                    onActivated: panel.toggleDetail("cpu", cpuModule)
                }

                StatusRing {
                    id: memoryModule
                    x: panel.moduleAxis - width / 2
                    y: Math.round(clockModule.y - 150
                                  - holographicUiLayer.batterySpacing - height / 2)
                    symbol: "録"
                    value: status.memoryUsage
                    accessibleName: "Memory"
                    expanded: panel.expandedModule === "memory"
                    expansionGlow: panel.moduleGlowFor("memory")
                    onActivated: panel.toggleDetail("memory", memoryModule)
                }

                StatusRing {
                    id: audioModule
                    x: panel.moduleAxis - width / 2
                    y: Math.round(clockModule.y - 100
                                  - holographicUiLayer.batterySpacing - height / 2)
                    symbol: status.audioMuted ? "静" : "音"
                    value: status.audioVolume
                    valueTransitionMs: Config.audioGaugeTransitionMs
                    valueTransitionEasing: Easing.OutCubic
                    accessibleName: status.audioMuted ? "Audio muted" : "Audio"
                    subdued: status.audioMuted
                    expanded: panel.expandedModule === "audio"
                    expansionGlow: panel.moduleGlowFor("audio")
                    wheelEnabled: true
                    onActivated: panel.toggleDetail("audio", audioModule)
                    onWheelAdjusted: steps => status.setAudioVolume(
                        status.audioVolume + steps * 0.05)
                }

                StatusRing {
                    id: networkModule
                    x: panel.moduleAxis - width / 2
                    y: Math.round(clockModule.y - 50
                                  - holographicUiLayer.batterySpacing - height / 2)
                    symbol: "信"
                    value: status.networkName.length > 0 ? 1.0 : 0.0
                    accessibleName: status.networkName.length > 0
                                    ? "Network " + status.networkName
                                    : "Network disconnected"
                    subdued: status.networkName.length === 0
                    expanded: panel.expandedModule === "network"
                    expansionGlow: panel.moduleGlowFor("network")
                    onActivated: panel.toggleDetail("network", networkModule)
                }

                StatusRing {
                    id: batteryModule
                    visible: status.batteryPresent
                    x: panel.moduleAxis - width / 2
                    y: Math.round(clockModule.y - 50 - height / 2)
                    symbol: status.batteryStatus === "Charging" ? "充" : "電"
                    value: status.batteryLevel
                    accessibleName: "Battery"
                    subdued: status.batteryLevel <= 0.15
                    expanded: panel.expandedModule === "battery"
                    expansionGlow: panel.moduleGlowFor("battery")
                    onActivated: panel.toggleDetail("battery", batteryModule)
                }
            }

            // Layer 3: expanded holographic projection.
            DetailOverlay {
                id: detailOverlay
                x: panel.detailAxis
                y: panel.detailY
                moduleName: panel.expandedModule
                presented: panel.detailPresented
                projectionOpacity: panel.detailOpacity
                cpuUsage: status.cpuUsage
                cpuCoreUsage: status.cpuCoreUsage
                memoryUsage: status.memoryUsage
                memoryUsedGiB: status.memoryUsedGiB
                memoryTotalGiB: status.memoryTotalGiB
                audioVolume: status.audioVolume
                audioMuted: status.audioMuted
                networkName: status.networkName
                batteryLevel: status.batteryLevel
                batteryStatus: status.batteryStatus
                batteryTimeMinutes: status.batteryTimeMinutes
                currentDate: clock.date
                tetherY: panel.detailTetherY
                onAudioVolumeRequested: value => status.setAudioVolume(value)
                onAudioMuteRequested: status.toggleAudioMute()
            }

            DetailOverlay {
                id: outgoingDetailOverlay
                x: panel.detailAxis
                y: panel.outgoingY
                moduleName: panel.outgoingModule
                presented: panel.outgoingPresented
                projectionOpacity: panel.outgoingOpacity
                cpuUsage: status.cpuUsage
                cpuCoreUsage: status.cpuCoreUsage
                memoryUsage: status.memoryUsage
                memoryUsedGiB: status.memoryUsedGiB
                memoryTotalGiB: status.memoryTotalGiB
                audioVolume: status.audioVolume
                audioMuted: status.audioMuted
                networkName: status.networkName
                batteryLevel: status.batteryLevel
                batteryStatus: status.batteryStatus
                batteryTimeMinutes: status.batteryTimeMinutes
                currentDate: clock.date
                tetherY: panel.outgoingTetherY
            }

            Connections {
                target: root
                function onIpcRequested(action, moduleName) {
                    panel.handleIpcRequest(action, moduleName);
                }
            }
            Connections {
                target: cpuModule
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
            Connections {
                target: memoryModule
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
            Connections {
                target: audioModule
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
            Connections {
                target: networkModule
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
            Connections {
                target: batteryModule
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
            Connections {
                target: clockModule
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
            Connections {
                target: status
                function onBatteryPresentChanged() {
                    if (!status.batteryPresent && panel.expandedModule === "battery")
                        panel.closeDetail();
                }
            }
            Connections {
                target: detailOverlay
                function onHoveredChanged() { panel.scheduleAutoClose(); }
            }
        }
    }
}
