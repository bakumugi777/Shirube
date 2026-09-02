import QtQuick

Translate {
    id: root

    property real amplitude: Config.floatingAmplitude
    property int period: Config.floatingPeriodMs
    property bool reverse: false

    y: reverse ? amplitude : -amplitude

    SequentialAnimation on y {
        id: drift
        running: Config.animationsEnabled === true
              && Config.ambientAnimationEnabled === true
              && Config.floatingEnabled && root.amplitude > 0
        loops: Animation.Infinite

        NumberAnimation {
            to: root.reverse ? -root.amplitude : root.amplitude
            duration: Math.max(1000, root.period / 2)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: root.reverse ? root.amplitude : -root.amplitude
            duration: Math.max(1000, root.period / 2)
            easing.type: Easing.InOutSine
        }

        onStopped: root.y = 0
    }
}
