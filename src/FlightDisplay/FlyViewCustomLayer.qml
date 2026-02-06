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

    // --- 状态控制变量 ---
    property bool toolsExpanded:    false
    property bool taskPanelShow:    false // 控制左侧任务面板是否显示

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // --------------------------------------------------------
    // 1. 【新增】左侧可收缩任务面板 (1/4 矩形)
    // --------------------------------------------------------
    Rectangle {
        id:                 taskModule
        anchors.verticalCenter: parent.verticalCenter

        // 逻辑：X 坐标 = 官方左侧栏占用的宽度 + 10 像素
        // 尺寸：宽度设为屏幕 1/4
        width:              Math.min(parent.width / 4, 300)
        height:             contentColumn.height + 40

        // --- 核心动画逻辑：滑出效果 ---
        // 展开时：避开左边栏；收起时：滑到屏幕左侧外面
        x: taskPanelShow ? (parentToolInsets.leftEdgeCenterInset + 10) : -width

        Behavior on x {
            NumberAnimation { duration: 500; easing.type: Easing.OutQuint }
        }

        color:              Qt.rgba(0.1, 0.1, 0.1, 0.8)
        radius:             8
        border.color:       Qt.rgba(1, 1, 1, 0.2)
        border.width:       1
        visible:            globals.activeVehicle && !toolDrawer.visible

        ColumnLayout {
            id:             contentColumn
            anchors.centerIn: parent
            width:          parent.width - 20
            spacing:        15

            QGCLabel {
                text: "作业模式"
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                color: "white"
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "white"; opacity: 0.2 }

            // 模式按钮 - 航线
            QGCButton {
                Layout.fillWidth: true
                text: "自动航线作业"
                onClicked: { taskPanelShow = false; mainWindow.showPlanView() }
            }

            // 模式按钮 - 环绕
            QGCButton {
                Layout.fillWidth: true
                text: "定点环绕监控"
                onClicked: {
                    globals.activeVehicle.sendCommand(globals.activeVehicle.defaultComponentId, MAVLink.MAV_CMD_DO_ORBIT, true, 50, 10)
                }
            }

            // 模式按钮 - 退出当前任务
            QGCButton {
                Layout.fillWidth: true
                text: "结束当前任务"
                onClicked: {
                    globals.activeVehicle.sendCommand(globals.activeVehicle.defaultComponentId, MAVLink.MAV_CMD_MISSION_START, true, 0, 0)
                }
            }
        }
    }

    // --------------------------------------------------------
    // 2. 右上角控制栏 (增加任务切换开关)
    // --------------------------------------------------------
    PositionSource { id: gcsPositionSource; active: false; updateInterval: 1000 }

    Row {
        id:                 controlRow
        anchors.right:      parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        anchors.top:        parent.top
        //anchors.topMargin:  toolDrawer.visible ? -height : (ScreenTools.defaultFontPixelHeight * 0.5)
        anchors.topMargin:  toolDrawer.visible ? -height : (ScreenTools.toolbarHeight + 10)

        layoutDirection:    Qt.RightToLeft
        spacing:            ScreenTools.defaultFontPixelWidth * 1.2
        z:                  1000

        readonly property real btnSize: ScreenTools.defaultFontPixelHeight * 2.6

        // A. [主开关]
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: toolsExpanded ? Qt.rgba(0.2, 0.2, 0.2, 0.8) : Qt.rgba(0.1, 0.1, 0.1, 0.6)
            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: toolsExpanded ? "/res/buttonRight_position.svg" : "/res/buttonLeft_position.svg"
                onClicked: toolsExpanded = !toolsExpanded
            }
        }

        // B. 【新增：任务面板开关】
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: taskPanelShow ? qgcPal.colorGreen : Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/qmlimages/Plan.svg" // 使用任务图标
                onClicked: taskPanelShow = !taskPanelShow
            }
        }

        // C. [设置按钮]
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/res/gear-black.svg"
                onClicked: if(mainWindow.allowViewSwitch()) mainWindow.showSettingsTool()
            }
        }

        // D. [GCS定位]
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/res/QGCLogoFull.png"
                onClicked: gcsPositionSource.start()
            }
        }
        // 6. [飞机] 居中飞机位置
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/res/vehi.png"
                onClicked: {
                    if (globals.activeVehicle && globals.activeVehicle.coordinate.isValid) {
                        mapControl.center = globals.activeVehicle.coordinate
                    }
                }
            }
        }

        // 7. [载荷] 抛投控制
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.3, 0.1, 0.1, 0.8) // 动作按钮稍微带点暗红色，提醒功能
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            border.color: Qt.rgba(1, 0, 0, 0.3)
            Behavior on opacity { NumberAnimation { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/res/GripperGrab.svg"
                onClicked: {
                    if (globals.activeVehicle) {
                        globals.activeVehicle.sendCommand(
                            globals.activeVehicle.defaultComponentId,
                            MAVLink.MAV_CMD_DO_SET_SERVO,
                            true,
                            9, 2000
                        )
                    }
                }
            }
        }
    }
}