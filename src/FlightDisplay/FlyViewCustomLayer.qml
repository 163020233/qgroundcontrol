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

    // // --- 背景遮罩 (点击外部关闭) ---
    // MouseArea {
    //     anchors.fill: parent
    //     enabled:      shoutingPanelShow
    //     visible:      shoutingPanelShow
    //     onClicked:    shoutingPanelShow = false
    // }

    // --- 喊话器精简管理面板 ---
    Rectangle {
        id:                 shoutingTaskModule
        width:              280 // 固定宽度，更加小巧
        height:             Math.min(parent.height * 0.7, 480) // 限制最高高度

        // 居中逻辑
        x: shoutingPanelShow ? (parent.width - width) / 2 : parent.width
        y: (parent.height - height) / 2

        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        opacity:            shoutingPanelShow ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        color:              Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.95)
        radius:             10
        border.color:       Qt.rgba(1, 1, 1, 0.15)
        visible:            globals.activeVehicle && (opacity > 0)

        ColumnLayout {
            anchors.fill:       parent
            anchors.margins:    12
            spacing:            8 // 紧凑间距

            // --- 1. 顶部标题与状态 ---
            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: "远程喊话控制"; font.pointSize: 11; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: ShoutingManager.connected ? "#00FF00" : "#666666"
                }
                QGCLabel {
                    text: ShoutingManager.connected ? "在线" : "离线"
                    font.pointSize: 9
                    color: ShoutingManager.connected ? "#00FF00" : "gray"
                }
            }

            // --- 2. 紧凑连接区 ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                QGCTextField {
                    id:             ipInput
                    text:           "192.168.1.20"
                    Layout.fillWidth: true
                    font.pointSize: 9
                    height:         25
                    enabled:        !ShoutingManager.connected
                }
                QGCButton {
                    // 动态文字：根据状态显示
                    text: {
                        if (ShoutingManager.connected) return "断开"
                        return "连接"
                    }

                    // 动态颜色：连上变灰，没连上变绿
                    primary: !ShoutingManager.connected

                    onClicked: {
                        if (ShoutingManager.connected) {
                            ShoutingManager.disconnectDevice()
                        } else {
                            // 点击后先显示一条提示，防止用户以为没点到
                            ShoutingManager.connectToDevice(ipInput.text)
                        }
                    }
                }

                // 增加一个明显的错误文字提示
                QGCLabel {
                    Layout.fillWidth: true
                    text: ShoutingManager.lastLog
                    color: ShoutingManager.connected ? "#00FF00" : "#FF6666" // 错误时显示淡红色
                    font.pointSize: 8
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            // --- 3. 音量与喊话 (并排显示省空间) ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                QGCLabel { text: "音量: " + Math.round(ShoutingManager.currentVolume); font.pointSize: 5 }
                QGCSlider {
                    Layout.fillWidth: true
                    from: 1; to: 100
                    value: ShoutingManager.currentVolume
                    onMoved: ShoutingManager.currentVolume = value
                }
            }

            // --- 4. 核心：按住喊话按钮 (缩小版) ---
            QGCButton {
                id:             micBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 25 // 高度大幅度缩小
                text:           pressed ? "正在送话..." : "按住 喊话"
                enabled:        ShoutingManager.connected

                background: Rectangle {
                    radius: 6
                    color:  micBtn.pressed ? "#AA3333" : (micBtn.enabled ? qgcPal.button : "#222222")
                }
                onPressed:      ShoutingManager.startMic()
                onReleased:     ShoutingManager.stopMic()
            }

            // --- 5. 文件列表区 (高度自适应) ---
            Rectangle {
                          id:             listBorder
                          Layout.fillWidth: true
                          Layout.fillHeight: true       // 尽量撑开
                          Layout.minimumHeight: 20     // 【关键：确保组件不会因为挤压而消失】
                          Layout.preferredHeight: 40    // 建议高度

                          color:          Qt.rgba(0, 0, 0, 0.2)
                          radius:         6
                          border.color:   Qt.rgba(1, 1, 1, 0.1)
                          clip:           true

                          ListView {
                              id:             fileListView
                              anchors.fill:   parent
                              anchors.margins: 2 // 留一点内边距
                              model:          ShoutingManager.playList
                              spacing:        4

                              // 滚动条保护
                              ScrollBar.vertical: ScrollBar {
                                  id: listScrollBar
                                  policy: ScrollBar.AsNeeded
                              }

                              delegate: Rectangle {
                                  // 如果滚动条显示，宽度自动缩减，防止遮挡
                                  width:  fileListView.width - (listScrollBar.visible ? 12 : 5)
                                  height: 25
                                  color:  Qt.rgba(1, 1, 1, 0.05)
                                  radius: 4
                                  anchors.horizontalCenter: parent.horizontalCenter

                                  RowLayout {
                                      anchors.fill: parent
                                      anchors.margins: 5
                                      spacing: 5

                                      QGCLabel {
                                          text: {
                                              var n = modelData.name || ""
                                              return n.substring(n.lastIndexOf('/') + 1)
                                          }
                                          Layout.fillWidth: true
                                          font.pointSize: 9
                                          elide: Text.ElideRight
                                          color: "white"
                                      }

                                      QGCButton {
                                          text: "播"
                                          Layout.preferredWidth: 28
                                          Layout.preferredHeight: 25
                                          onClicked: ShoutingManager.repeatPath(modelData.name)
                                      }

                                      QGCButton {
                                          text: "删"
                                          Layout.preferredWidth: 28
                                          Layout.preferredHeight: 25
                                          onClicked: ShoutingManager.deleteMp3(modelData.name)
                                      }
                                  }
                              }
                          }

                          // 列表为空时的提示
                          QGCLabel {
                              anchors.centerIn: parent
                              text: "无文件或未连接"
                              visible: fileListView.count === 0
                              font.pointSize: 9
                              color: "gray"
                          }
                      }

            // --- 6. 底部功能组 (2x2 栅格) ---
            GridLayout {
                columns:        2
                Layout.fillWidth: true
                rowSpacing:     3    // 极小行距
                columnSpacing:  3    // 极小列距

                // 定义按钮的统一高度变量，方便修改
                readonly property int btnHeight: 28

                QGCButton {
                    text: "同步列表" // 缩减文字长度
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.btnHeight
                    font.pointSize: 8  // 进一步缩小字体
                    onClicked: ShoutingManager.refreshPlayList()
                }

                QGCButton {
                    text: "上传音频"
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.btnHeight
                    font.pointSize: 8
                    onClicked: filePicker.open()
                }

                QGCButton {
                    text: "一键警报"
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.btnHeight
                    font.pointSize: 8
                    primary: true
                    onClicked: ShoutingManager.sendAlarm()
                }

                QGCButton {
                    text: "停止播放"
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.btnHeight
                    font.pointSize: 8
                    onClicked: ShoutingManager.stopPlayer()
                }
            }

            // 关闭按钮
            QGCButton {
                text:           "收起面板"
                Layout.fillWidth: true
                Layout.preferredHeight: 24 // 极致高度
                font.pointSize: 8
                onClicked:      shoutingPanelShow = false

                // 这种超薄按钮建议去掉背景边框，或者用简单的线条
                background: Rectangle {
                    color:  parent.pressed ? "#444444" : "transparent"
                    border.color: Qt.rgba(1,1,1,0.2)
                    radius: 4
                }
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
