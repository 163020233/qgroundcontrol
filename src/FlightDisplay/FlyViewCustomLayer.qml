import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.Vehicle
import QtQuick.Dialogs // 必须导入，用于弹出文件选择器

Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    // --- 状态控制变量 ---
    property bool toolsExpanded:    false
    property bool taskPanelShow:    false // 控制左侧任务面板是否显示

    // --- 喊话器对外变量
    property bool shoutingPanelShow: false // 控制喊话器相关任务面板是否显示
    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    FileDialog {
        id:             filePicker
        title:          "选择要上传的 MP3 音频"
        nameFilters:    [ "音频文件 (*.mp3)", "所有文件 (*)" ]
        // 用户选好文件点击“打开”后触发
        onAccepted: {
            // 获取文件路径 (注意：Qt 6 返回的是 url 格式，需要处理)
            var path = selectedFile.toString();
            // 去掉 file:/// 前缀以适配 C++ 路径读取
            if (Qt.platform.os === "windows") {
                path = path.replace("file:///", "");
            } else {
                path = path.replace("file://", "");
            }
            ShoutingManager.uploadMp3(path);
        }
    }

    // --------------------------------------------------------
    // 喊话器控制面板 (1/4 矩形)
    // --------------------------------------------------------
    Rectangle {
        id:                 shoutingTaskModule
        anchors.verticalCenter: parent.verticalCenter

        // 动态计算高度，防止超出屏幕
        width:              Math.min(parent.width / 3.5, 320)
        height:             parent.height * 0.8

        x: shoutingPanelShow ? (parent.width - width - 10) : parent.width
        Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

        color:              qgcPal.window   // 使用 QGC 标准配色
        opacity:            0.95
        radius:             8
        border.color:       qgcPal.globalTheme === QGCPalette.Light ? "black" : "white"
        border.width:       1
        visible:            globals.activeVehicle && (x < parent.width)

        // 内部间距布局
        ColumnLayout {
            anchors.fill:       parent
            anchors.margins:    15
            spacing:            12

            // --- 标题栏 ---
            QGCLabel {
                text:           "远程喊话系统"
                font.pointSize: 14
                font.bold:      true
                Layout.alignment: Qt.AlignHCenter
            }

            // --- 1. 连接控制区 ---
            RowLayout {
                Layout.fillWidth: true
                QGCTextField {
                    id:             ipField
                    text:           "192.168.1.20"
                    Layout.fillWidth: true
                    placeholderText: "设备 IP"
                    enabled:        !ShoutingManager.connected
                }
                QGCButton {
                    text:           ShoutingManager.connected ? "断开" : "连接"
                    primary:        !ShoutingManager.connected
                    onClicked: {
                        if (ShoutingManager.connected) {
                            ShoutingManager.disconnectDevice()
                        } else {
                            ShoutingManager.connectToDevice(ipField.text)
                        }
                    }
                }
            }

            // --- 2. 实时音量控制 ---
            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: "音量"; font.pointSize: 10 }
                QGCSlider {
                    Layout.fillWidth: true
                    from:           1
                    to:             100
                    value:          ShoutingManager.currentVolume
                    enabled:        ShoutingManager.connected
                    onMoved:        ShoutingManager.currentVolume = value // 触发 C++ WRITE 函数
                }
                QGCLabel { text: Math.round(ShoutingManager.currentVolume); width: 25 }
            }

            // --- 3. 核心功能：按住喊话 ---
            QGCButton {
                id:             micBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                text:           pressed ? "【正在送话...】" : "【按住实时喊话】"
                enabled:        ShoutingManager.connected
                // 按钮颜色在按下时变红提示
                background: Rectangle {
                    color: micBtn.pressed ? "#FF4444" : (micBtn.enabled ? qgcPal.button : "#444444")
                    radius: 4
                }
                onPressed:      ShoutingManager.startMic()
                onReleased:     ShoutingManager.stopMic()
            }

            // --- 4. MP3 播放列表 (高级功能) ---
            QGCLabel { text: "存储卡音频列表"; font.bold: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true // 自动撑开
                color:          Qt.rgba(0,0,0,0.2)
                radius:         4
                clip:           true

                ListView {
                    id:             playListView
                    anchors.fill:   parent
                    model:          ShoutingManager.playList
                    delegate: Item {
                        width: playListView.width; height: 40
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            QGCLabel {
                                text:           modelData.name
                                Layout.fillWidth: true
                                elide:          Text.ElideRight
                                font.pointSize: 9
                            }
                            QGCButton {
                                text: "播"
                                Layout.preferredWidth: 40
                                onClicked: ShoutingManager.playByPath("/xmedia/mp3/" + modelData.name)
                            }
                            QGCButton {
                                text: "删"
                                Layout.preferredWidth: 40
                                onClicked: ShoutingManager.deleteMp3(modelData.name)
                            }
                        }
                    }
                    // 列表为空时提示
                    QGCLabel {
                        anchors.centerIn: parent
                        text: "列表为空，请刷新"
                        visible: parent.count === 0
                        opacity: 0.5
                    }
                }
            }

            // --- 5. 底部操作栏 ---
            RowLayout {
                Layout.fillWidth: true
                QGCButton {
                    text: "刷新列表"
                    Layout.fillWidth: true
                    onClicked: ShoutingManager.refreshPlayList()
                }
                // 【新增：上传按钮】
                QGCButton {
                    text:           "上传音频"
                    Layout.fillWidth: true
                    enabled:        ShoutingManager.connected // 没连上不能传
                    onClicked:      filePicker.open() // 触发弹出文件夹选择
                }

                QGCButton {
                    text: "一键警报"
                    Layout.fillWidth: true
                    onClicked: ShoutingManager.sendAlarm()
                }
            }

            QGCButton {
                text:           "关闭面板"
                Layout.fillWidth: true
                onClicked:      {
                    shoutingPanelShow = false
                    ShoutingManager.disconnectDevice()
                }
            }
            // --- 6. 状态提示 (可选) ---
            QGCLabel {
                Layout.fillWidth: true
                text:           ShoutingManager.lastLog
                font.pointSize: 8
                color:          "gray"
                horizontalAlignment: Text.AlignHCenter
                elide:          Text.ElideRight
            }
        }
    }
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
            width: controlRow.btnSize;
            height: width; radius: width / 2
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
            width: controlRow.btnSize;
            height: width; radius: width / 2
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
        // 8. [载荷] 喊话控制
        Rectangle {
            width:          controlRow.btnSize;
            height: width; radius: width / 2
            // 逻辑：如果面板打开，颜色变绿提示正在操作
            color:          shoutingPanelShow ? Qt.rgba(0.1, 0.5, 0.1, 0.8) : Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:        toolsExpanded
            opacity:        toolsExpanded ? 1 : 0
            border.color:   shoutingPanelShow ? "white" : Qt.rgba(1, 1, 1, 0.2)
            border.width:   shoutingPanelShow ? 2 : 0

            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color   { ColorAnimation  { duration: 200 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                // 注意：你需要确保资源文件里有这个图标，或者先用 text 代替测试
                icon.source:           "/res/mic.svg"
                onClicked: {
                    shoutingPanelShow = !shoutingPanelShow
                    if (shoutingPanelShow) {
                        taskPanelShow = false // 打开喊话器时，关闭作业模式面板
                    }
                }
            }
        }
    }
}