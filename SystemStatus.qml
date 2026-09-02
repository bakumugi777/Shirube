import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string audioHelperPath:
        String(Qt.resolvedUrl("helpers/shirube-audio-rms"))
        .replace(/^file:\/\//, "")

    property real cpuUsage: 0
    property var cpuCoreUsage: []
    property real memoryUsage: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property bool audioMuted: false
    property real audioVolume: 0
    property real audioLevel: 0
    property real audioTargetLevel: 0
    property bool audioRising: false
    property double audioLastSampleMs: 0

    // RMS samples arrive at 10 Hz. Interpolate between them so brightness is
    // continuous at the light-field frame rate instead of changing in steps.
    Behavior on audioLevel {
        NumberAnimation {
            duration: root.audioRising
                    ? (Config.audioReactionAttackMs || 90)
                    : (Config.audioReactionReleaseMs || 380)
            easing.type: root.audioRising ? Easing.OutCubic : Easing.InOutSine
        }
    }
    property string networkName: ""
    property bool batteryPresent: false
    property real batteryLevel: 0
    property string batteryStatus: ""
    property int batteryTimeMinutes: -1
    property var workspaces: []
    property int activeWorkspace: -1

    property var _previousCpu: null
    property var _previousCpuCores: ({})

    function cpuCounters(fields) {
        const values = fields.map(Number);
        return {
            idle: values[3] + (values[4] || 0),
            // guest/guest_nice are already included in user/nice.
            total: values.slice(0, 8).reduce((sum, value) => sum + value, 0)
        };
    }

    function updateSystem(raw) {
        const lines = raw.trim().split("\n");
        if (lines.length < 2)
            return;

        const aggregateLine = lines.find(line => /^cpu\s/.test(line));
        if (aggregateLine === undefined)
            return;
        const aggregate = cpuCounters(aggregateLine.trim().split(/\s+/).slice(1));
        if (_previousCpu !== null) {
            const totalDelta = aggregate.total - _previousCpu.total;
            const idleDelta = aggregate.idle - _previousCpu.idle;
            if (totalDelta > 0) {
                const sample = 1 - idleDelta / totalDelta;
                cpuUsage = cpuUsage === 0 ? sample : cpuUsage * 0.65 + sample * 0.35;
            }
        }
        _previousCpu = aggregate;

        const nextPreviousCores = {};
        const nextCoreUsage = [];
        for (let i = 0; i < lines.length; ++i) {
            const match = lines[i].match(/^cpu(\d+)\s+(.+)$/);
            if (!match)
                continue;
            const index = Number(match[1]);
            const counters = cpuCounters(match[2].trim().split(/\s+/));
            const previous = _previousCpuCores[index];
            let usage = cpuCoreUsage[index] !== undefined ? cpuCoreUsage[index] : 0;
            if (previous !== undefined) {
                const totalDelta = counters.total - previous.total;
                const idleDelta = counters.idle - previous.idle;
                if (totalDelta > 0) {
                    const sample = Math.max(0, Math.min(1, 1 - idleDelta / totalDelta));
                    usage = usage === 0 ? sample : usage * 0.65 + sample * 0.35;
                }
            }
            nextPreviousCores[index] = counters;
            nextCoreUsage[index] = usage;
        }
        _previousCpuCores = nextPreviousCores;
        cpuCoreUsage = nextCoreUsage;

        const memory = {};
        for (let i = 1; i < lines.length; ++i) {
            const match = lines[i].match(/^([^:]+):\s+(\d+)/);
            if (match)
                memory[match[1]] = Number(match[2]);
        }
        if (memory.MemTotal > 0) {
            memoryUsage = 1 - memory.MemAvailable / memory.MemTotal;
            memoryTotalGiB = memory.MemTotal / 1048576;
            memoryUsedGiB = (memory.MemTotal - memory.MemAvailable) / 1048576;
        }
    }

    function updateWorkspaces(raw) {
        try {
            const source = JSON.parse(raw);
            if (!Array.isArray(source))
                return;

            const result = [];
            let focused = -1;
            for (let i = 0; i < source.length; ++i) {
                const workspace = source[i];
                // Niri uses idx; Hyprland uses id. Named/special Hyprland
                // workspaces have negative IDs and are omitted for now.
                const number = workspace.idx !== undefined
                             ? Number(workspace.idx)
                             : Number(workspace.id);
                if (!Number.isFinite(number) || number <= 0)
                    continue;
                if (result.indexOf(number) === -1)
                    result.push(number);
                if (workspace.is_focused === true || workspace.is_active === true)
                    focused = number;
            }
            result.sort((a, b) => a - b);
            workspaces = result;
            if (focused > 0)
                activeWorkspace = focused;
        } catch (error) {
            // Keep the last valid state during compositor reloads.
        }
    }

    function updateHyprlandActive(raw) {
        try {
            const workspace = JSON.parse(raw);
            const number = Number(workspace.id);
            if (Number.isFinite(number) && number > 0)
                activeWorkspace = number;
        } catch (error) {
        }
    }

    function updateAudio(raw) {
        audioMuted = raw.indexOf("[MUTED]") !== -1;
        const match = raw.match(/Volume:\s*([0-9]+(?:\.[0-9]+)?)/);
        if (match)
            audioVolume = Math.max(0, Math.min(1, Number(match[1])));
    }

    function updateAudioLevel(raw) {
        const rms = Number(String(raw).trim());
        if (!Number.isFinite(rms))
            return;
        // Remove the monitor's noise floor and compress normal listening
        // levels into a restrained 0..1 control signal. Attack is quicker
        // than release, but both remain deliberately soft.
        const target = Math.max(0, Math.min(1, (rms - 0.0035) * 8.0));
        audioRising = target > audioTargetLevel;
        const blend = audioRising ? 0.68 : 0.11;
        audioTargetLevel += (target - audioTargetLevel) * blend;
        audioLevel = audioTargetLevel;
        audioLastSampleMs = Date.now();
    }

    function updateBattery(raw) {
        const line = raw.trim();
        if (line.length === 0) {
            batteryPresent = false;
            batteryLevel = 0;
            batteryStatus = "";
            batteryTimeMinutes = -1;
            return;
        }
        const fields = line.split("|");
        const capacity = Number(fields[0]);
        batteryPresent = Number.isFinite(capacity);
        batteryLevel = batteryPresent
                     ? Math.max(0, Math.min(1, capacity / 100)) : 0;
        batteryStatus = fields[1] || "Unknown";
        const remaining = Number(fields[2]);
        batteryTimeMinutes = Number.isFinite(remaining) && remaining >= 0
                           ? Math.round(remaining) : -1;
    }

    function refreshWorkspaces() {
        if (!workspaceProcess.running)
            workspaceProcess.running = true;
        if (!hyprlandActiveProcess.running)
            hyprlandActiveProcess.running = true;
    }

    function scheduleWorkspaceRefresh() {
        // Compositors may emit several records for one user action. Collapse
        // that burst into one snapshot instead of spawning a command per line.
        workspaceEventDebounce.restart();
    }

    function activateWorkspace(number) {
        if (!Number.isFinite(number) || number <= 0)
            return;
        activeWorkspace = number;
        workspaceActionProcess.exec(["sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ]; then niri msg action focus-workspace \"$1\"; "
            + "elif [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then hyprctl dispatch workspace \"$1\"; fi",
            "shirube-workspace", String(number)]);
    }

    function setAudioVolume(value) {
        const clamped = Math.max(0, Math.min(1, value));
        audioVolume = clamped;
        audioSetProcess.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                              Math.round(clamped * 100) + "%"]);
    }

    function toggleAudioMute() {
        audioMuted = !audioMuted;
        audioMuteProcess.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    property Process systemProcess: Process {
        command: ["sh", "-c", "awk '/^cpu/ { print }' /proc/stat; cat /proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: root.updateSystem(text) }
    }

    property Process audioProcess: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: root.updateAudio(text)
        }
    }

    property Process networkProcess: Process {
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: root.networkName = text.trim().split("\n")[0] || ""
        }
    }

    property Process batteryProcess: Process {
        command: ["sh", "-c",
                  "for d in /sys/class/power_supply/*; do "
                  + "[ -r \"$d/type\" ] || continue; "
                  + "[ \"$(cat \"$d/type\")\" = Battery ] || continue; "
                  + "cap=$(cat \"$d/capacity\" 2>/dev/null); "
                  + "state=$(cat \"$d/status\" 2>/dev/null); "
                  + "now=$(cat \"$d/energy_now\" 2>/dev/null || cat \"$d/charge_now\" 2>/dev/null); "
                  + "full=$(cat \"$d/energy_full\" 2>/dev/null || cat \"$d/charge_full\" 2>/dev/null); "
                  + "rate=$(cat \"$d/power_now\" 2>/dev/null || cat \"$d/current_now\" 2>/dev/null); "
                  + "mins=-1; if [ \"${rate:-0}\" -gt 0 ] 2>/dev/null; then "
                  + "if [ \"$state\" = Charging ] && [ -n \"$full\" ]; then base=$((full-now)); else base=$now; fi; "
                  + "mins=$((base * 60 / rate)); fi; "
                  + "printf '%s|%s|%s\\n' \"$cap\" \"$state\" \"$mins\"; exit; done"]
        stdout: StdioCollector { onStreamFinished: root.updateBattery(text) }
    }

    property Process workspaceProcess: Process {
        command: ["sh", "-c",
                  "if [ -n \"$NIRI_SOCKET\" ]; then niri msg -j workspaces; "
                  + "elif [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then hyprctl -j workspaces; "
                  + "else printf '[]\\n'; fi"]
        stdout: StdioCollector { onStreamFinished: root.updateWorkspaces(text) }
    }

    property Process hyprlandActiveProcess: Process {
        command: ["sh", "-c",
                  "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then hyprctl -j activeworkspace; "
                  + "else printf '{}\\n'; fi"]
        stdout: StdioCollector { onStreamFinished: root.updateHyprlandActive(text) }
    }

    property Process workspaceActionProcess: Process {}
    property Process audioSetProcess: Process {}
    property Process audioMuteProcess: Process {}

    // Keep one low-rate monitor stream alive instead of launching an analyzer.
    // Prefer the native binary reader; retain the shell analyzer as fallback.
    // for every visual frame. The 2 kHz mono stream is intentionally
    // bass-weighted; only a 20 Hz RMS value leaves this pipeline.
    // If PipeWire or its tools are unavailable, the process sleeps and the
    // visual level simply remains at zero.
    property Process audioLevelProcess: Process {
        running: Config.animationsEnabled === true
              && Config.audioReactionEnabled === true
        command: ["sh", "-c",
                  "if ! command -v pw-record >/dev/null 2>&1 || "
                  + "! command -v wpctl >/dev/null 2>&1; then exec sleep infinity; fi; "
                  + "helper=$1; "
                  + "while :; do "
                  + "target=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | "
                  + "sed -n 's/^[[:space:]]*\\**[[:space:]]*node.name = \\\"\\(.*\\)\\\"/\\1/p' | head -n1); "
                  + "if [ -z \"$target\" ]; then sleep 30; continue; fi; "
                  + "pw-record --raw --format s16 --rate 2000 --channels 1 "
                  + "--latency 50ms --properties='stream.capture.sink=true' "
                  + "--target \"$target\" - 2>/dev/null | "
                  + "if [ -x \"$helper\" ]; then \"$helper\" 100; "
                  + "else stdbuf -oL od -An -v -w200 -t d2 | "
                  + "awk '{ for (i=1; i<=NF; i++) { sum += $i*$i; n++ } "
                  + "if (n >= 100) { printf \"%.6f\\n\", sqrt(sum/n)/32768; "
                  + "fflush(); sum=0; n=0 } }'; fi; sleep 5; done",
                  "shirube-audio", root.audioHelperPath]
        stdout: SplitParser {
            onRead: data => root.updateAudioLevel(data)
        }
    }

    // Both compositors expose a continuous event stream. The event payload is
    // only used as an invalidation signal; a fresh snapshot is then requested
    // so Niri and Hyprland share the same update path.
    property Process workspaceEventProcess: Process {
        running: true
        command: ["sh", "-c",
                  "if [ -n \"$NIRI_SOCKET\" ]; then exec niri msg -j event-stream; "
                  + "elif [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then "
                  + "exec socat -u UNIX-CONNECT:\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\" -; "
                  + "else exec sleep infinity; fi"]
        stdout: SplitParser {
            onRead: root.scheduleWorkspaceRefresh()
        }
    }

    property Timer workspaceEventDebounce: Timer {
        interval: 40
        repeat: false
        onTriggered: root.refreshWorkspaces()
    }

    property Timer systemTimer: Timer {
        interval: Config.systemUpdateMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!root.systemProcess.running) root.systemProcess.running = true
    }

    property Timer audioTimer: Timer {
        interval: Config.audioUpdateMs || 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!root.audioProcess.running) root.audioProcess.running = true
    }

    property Timer audioLevelDecayTimer: Timer {
        interval: 250
        repeat: true
        running: Config.animationsEnabled === true
              && Config.audioReactionEnabled === true
        onTriggered: {
            // Also returns the field to rest if the monitor disappears while
            // the long-running shell is waiting to reconnect.
            if (Date.now() - root.audioLastSampleMs > 450) {
                root.audioRising = false;
                root.audioTargetLevel *= 0.78;
                if (root.audioTargetLevel < 0.001)
                    root.audioTargetLevel = 0;
                root.audioLevel = root.audioTargetLevel;
            }
        }
    }

    property Timer networkTimer: Timer {
        interval: Config.networkUpdateMs || 6000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!root.networkProcess.running) root.networkProcess.running = true
    }

    property Timer batteryTimer: Timer {
        interval: Config.batteryUpdateMs || 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!root.batteryProcess.running) root.batteryProcess.running = true
    }

    // Workspace changes are interaction feedback, so they must not wait for
    // the slower desktop-status polling cycle.
    property Timer workspaceTimer: Timer {
        interval: Config.workspaceFallbackMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshWorkspaces();
        }
    }
}
