import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    // 1. 搬过来的私有变量：控制展开状态
    property bool toolsExpanded: false

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // 2. 搬过来的定位源
    PositionSource {
        id: gcsPositionSource
        active: false
        updateInterval: 1000
        onPositionChanged: {
            if (position.coordinate.isValid && mapControl) {
                mapControl.center = position.coordinate
                mapControl.zoomLevel = 18
                stop()
            }
        }
    }

    // 3. 搬过来的按钮布局
    // 逻辑：我们要把按钮放在右上角，但要避开 QGC 的 TopToolbar (topEdgeRightInset)
    Column {
        anchors.top:        parent.top
        anchors.right:      parent.right
        // 关键布局逻辑：利用 Insets 自动避让顶部栏
        anchors.topMargin:  parentToolInsets.topEdgeRightInset + ScreenTools.defaultFontPixelHeight
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        spacing:            ScreenTools.defaultFontPixelHeight / 2

        // 主切换按钮
        QGCToolBarButton {
            id: mainButton
            icon.source: toolsExpanded ? "/res/buttonRight_position.svg" : "/res/buttonLeft_position.svg"
            onClicked: toolsExpanded = !toolsExpanded
        }

        // 飞控定位按钮 (带动画显示)
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/res/vehi.png"
            Behavior on opacity { NumberAnimation { duration: 250 } }
            onClicked: {
                if (globals.activeVehicle && globals.activeVehicle.coordinate.isValid) {
                    mapControl.center = globals.activeVehicle.coordinate
                }
            }
        }

        // GCS定位按钮
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/res/QGCLogoFull.png"
            Behavior on opacity { NumberAnimation { duration: 250 } }
            onClicked: gcsPositionSource.start()
        }
    }
}