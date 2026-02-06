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

    property bool toolsExpanded: false

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

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

        anchors.top:        parent.top
        anchors.topMargin:  toolDrawer.visible ? -height : (ScreenTools.defaultFontPixelHeight * 0.5)

        opacity:            toolDrawer.visible ? 0 : 1
        visible:            opacity > 0

        layoutDirection:    Qt.RightToLeft
        spacing:            ScreenTools.defaultFontPixelWidth * 1.2 // 稍微加大间距，容纳圆形背景
        z:                  1000

        Behavior on anchors.topMargin { NumberAnimation { duration: 500; easing.type: Easing.OutQuad  } }
        Behavior on opacity { NumberAnimation { duration: 500 } }

        // --- 统一样式属性定义 ---
        readonly property real btnSize: ScreenTools.defaultFontPixelHeight * 2.6 // 统一圆圈大小

        // 1. [主开关]
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: toolsExpanded ? Qt.rgba(0.2, 0.2, 0.2, 0.8) : Qt.rgba(0.1, 0.1, 0.1, 0.6) // 展开和收起时底色微调
            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: toolsExpanded ? "/res/buttonRight_position.svg" : "/res/buttonLeft_position.svg"
                onClicked: toolsExpanded = !toolsExpanded
            }
        }

        // 2. [设置] 系统设置按钮
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.15, 0.15, 0.15, 0.7) // 灰度透明背景
            border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/res/gear-black.svg"
                onClicked: if(mainWindow.allowViewSwitch()) mainWindow.showSettingsTool()
            }
        }

        // 3. [任务] 计划视图
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/qmlimages/Plan.svg"
                onClicked: if (mainWindow.allowViewSwitch()) mainWindow.showPlanView()
            }
        }

        // 4. [3D] 视图切换
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: (viewer3DWindow && viewer3DWindow.isOpen) ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Viewer3D/City3DMapIcon.svg"
                onClicked: {
                    if(viewer3DWindow.isOpen) viewer3DWindow.close()
                    else viewer3DWindow.open()
                }
            }
        }

        // 5. [GCS] 居中地面站
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