import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.Vehicle

Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    // 控制展开状态
    property bool toolsExpanded: false

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // 定位源逻辑
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

    // --------------------------------------------------------
    // 右上角工业控制栏 (水平向左展开)
    // --------------------------------------------------------
    Row {
        id:                 controlRow
        anchors.right:      parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth

        // --- 【同步滑出逻辑】 ---
        anchors.top:        parent.top

        // 逻辑：当面板打开时，缩回到上方。高度加上 10 像素的偏移
        anchors.topMargin:  toolDrawer.visible ? -height : (ScreenTools.defaultFontPixelHeight * 0.5)

        opacity:            toolDrawer.visible ? 0 : 1
        visible:            opacity > 0

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 500; easing.type: Easing.OutQuad  }
        }
        Behavior on opacity {
            NumberAnimation { duration: 500 }
        }
        // ----------------------

        layoutDirection:    Qt.RightToLeft
        spacing:            ScreenTools.defaultFontPixelWidth
        z:                  1000

        // 1. [主开关]
        QGCToolBarButton {
            id: mainButton
            icon.source: toolsExpanded ? "/res/buttonRight_position.svg" : "/res/buttonLeft_position.svg"
            onClicked: toolsExpanded = !toolsExpanded
        }

        // --- 以下为从 ToolStripActionList 搬过来的工业功能 ---

        // 2. [设置] 系统设置按钮
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/res/gear-black.svg"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onClicked: {
                if(mainWindow.allowViewSwitch()) {
                    mainWindow.showSettingsTool() // 触发 MainRootWindow 的侧滑逻辑
                }
            }
        }

        // 3. [任务] 计划视图
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/qmlimages/Plan.svg"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onClicked: {
                if (mainWindow.allowViewSwitch()) {
                    mainWindow.showPlanView() // 切换到 PlanView.qml
                }
            }
        }

        // 4. [3D] 视图切换
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            // 根据 viewer3DWindow 状态切换图标
            icon.source: (viewer3DWindow && viewer3DWindow.isOpen) ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Viewer3D/City3DMapIcon.svg"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onClicked: {
                if(viewer3DWindow.isOpen) viewer3DWindow.close()
                else viewer3DWindow.open()
            }
        }

        // 5. [GCS] 居中地面站
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/res/QGCLogoFull.png"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onClicked: gcsPositionSource.start()
        }

        // 6. [飞机] 居中飞机位置
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/res/vehi.png"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onClicked: {
                if (globals.activeVehicle && globals.activeVehicle.coordinate.isValid) {
                    mapControl.center = globals.activeVehicle.coordinate
                }
            }
        }

        // 7. [载荷] 抛投控制 (示例：设置舵机9)
        QGCToolBarButton {
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            icon.source: "/res/GripperGrab.svg"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onClicked: {
                if (globals.activeVehicle) {
                    globals.activeVehicle.sendCommand(
                        globals.activeVehicle.defaultComponentId,
                        MAVLink.MAV_CMD_DO_SET_SERVO,
                        true,
                        9,    // 舵机号
                        2000  // 释放值
                    )
                }
            }
        }
    }
}