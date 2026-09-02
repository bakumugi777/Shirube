import QtQuick

Item {
    id: root
    required property string symbol
    required property string accessibleName
    property string caption: ""
    property bool subdued: false
    property bool expanded: false
    property real expansionGlow: expanded ? 1.0 : 0.0
    readonly property bool hovered: interaction.containsMouse
    signal activated()

    implicitWidth: 46
    implicitHeight: caption.length > 0 ? 54 : 40
    opacity: expanded ? 1.0
                      : hovered ? Config.hoverOpacity
                      : subdued ? Config.subduedOpacity : Config.idleOpacity
    Accessible.name: accessibleName
    Accessible.role: Accessible.StaticText

    Behavior on opacity {
        NumberAnimation {
            duration: root.expanded ? 150 : 360
            easing.type: root.expanded ? Easing.OutCubic : Easing.InOutSine
        }
    }

    Text {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        topPadding: 7
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
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        topPadding: 7
        text: root.symbol
        color: root.subdued ? Config.subduedTextColor : Config.brightTextColor
        style: Text.Outline
        styleColor: Qt.rgba(Config.accentColor.r, Config.accentColor.g,
                            Config.accentColor.b,
                            Math.min(1.0, ((root.subdued ? 0.26 : 0.64)
                          + 0.24 * root.expansionGlow) * Config.glowIntensity))
        font { family: Config.resolvedFontFamily; pixelSize: Config.moduleFontSize; weight: Config.fontWeight; letterSpacing: Config.letterSpacing }
    }

    Rectangle {
        x: 3
        y: 18
        width: 4
        height: 4
        rotation: 45
        color: Config.accentColor
        opacity: 0.58
    }

    Rectangle {
        x: 4.5
        y: 27
        width: 1
        height: 10
        color: Config.accentColor
        opacity: 0.24
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

    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
