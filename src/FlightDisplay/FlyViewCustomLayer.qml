import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.Vehicle
import QGroundControl.FlightDisplay
import QtQuick.Dialogs

Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    // --- 状态控制变量 ---
    property bool toolsExpanded:    false
    property bool taskPanelShow:    false // 控制左侧任务面板是否显示
    property alias planEditor:      _planEditor // 暴露给 FlyView 访问 addWaypointMode

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

        x: shoutingPanelShow ? (parent.width - width) / 2 : parent.width

        // 2. 透明度：配合显隐增加淡入淡出
        opacity: shoutingPanelShow ? 1.0 : 0.0

        // 3. 动画：当 x 坐标变化时执行平滑滑动
        Behavior on x {
            NumberAnimation { duration: 500; easing.type: Easing.OutQuint }
        }
        // 动画：透明度平滑过渡
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }

        // 4. 可见性优化：只有在屏幕内或正在移动时才渲染，节省性能
        visible: globals.activeVehicle && (shoutingPanelShow || opacity > 0)
        // --------------------------------------------------------

        // 1. 定义状态变量
        property bool showFileList: false

        // 2. 这里的宽度和位置不再写死，而是交给 States 处理
        height:             Math.min(parent.height * 0.8, 520)
        y:                  (parent.height - height) / 2

        color:              Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.98)
        radius:             12
        clip:               true

        // --------------------------------------------------------
        // 【核心优化：状态机模式】
        // --------------------------------------------------------
        states: [
            State {
                name: "collapsed"
                when: !shoutingTaskModule.showFileList
                PropertyChanges { target: shoutingTaskModule; width: 280 }
                PropertyChanges { target: fileListArea; visible: false; Layout.preferredWidth: 0 }
            },
            State {
                name: "expanded"
                when: shoutingTaskModule.showFileList
                PropertyChanges { target: shoutingTaskModule; width: 680 } // 展开后的总宽度
                PropertyChanges { target: fileListArea; visible: true; Layout.preferredWidth: 380 }
            }
        ]

        // 定义切换状态时的平滑过渡
        transitions: Transition {
            // 这里包含了对 width 的动画处理，会与上面的 x 坐标动画完美叠加
            NumberAnimation { properties: "width,Layout.preferredWidth"; duration: 400; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill:       parent
            anchors.margins:    15
            spacing:            showFileList ? 15 : 0 // 展开时才有间距

            // ======================== 左侧：控制面板 (固定宽度) ========================
            ColumnLayout {
                id:                 leftControlArea
                Layout.preferredWidth: 250
                Layout.fillHeight:     true

                QGCLabel {
                    text: "远程喊话控制"
                    font.pointSize: 12
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                // 连接信息状态
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Rectangle { width: 8; height: 8; radius: 4; color: ShoutingManager.connected ? "#00FF00" : "red" }
                    QGCLabel { text: ShoutingManager.connected ? "设备已连接" : "未连接"; font.pointSize: 9 }
                }

                // IP连接
                RowLayout {
                    Layout.fillWidth: true
                    QGCTextField { id: ipInput; text: "192.168.1.20"; Layout.fillWidth: true; enabled: !ShoutingManager.connected }
                    QGCButton {
                        text: ShoutingManager.connected ? "断开" : "连接"
                        onClicked: ShoutingManager.connected ? ShoutingManager.disconnectDevice() : ShoutingManager.connectToDevice(ipInput.text)
                    }
                }

                // 音量控制
                ColumnLayout {
                    Layout.fillWidth: true
                    QGCLabel { text: "输出音量: " + Math.round(ShoutingManager.currentVolume); font.pointSize: 9 }
                    QGCSlider { Layout.fillWidth: true; from: 0; to: 100; value: ShoutingManager.currentVolume; onMoved: ShoutingManager.currentVolume = value }
                }

                // 喊话按钮
                QGCButton {
                    id: micBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    text: pressed ? "正在向无人机送话..." : "按住 实时喊话"
                    enabled: ShoutingManager.connected
                    onPressed: ShoutingManager.startMic()
                    onReleased: ShoutingManager.stopMic()
                }

                // 功能网格
                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    columnSpacing: 8
                    rowSpacing: 8

                    QGCButton {
                        text:  "同步列表"
                        Layout.fillWidth: true
                        onClicked: {
                            //  实时触发：修改变量即刻进入 "expanded" 状态
                            shoutingTaskModule.showFileList = true
                            ShoutingManager.refreshPlayList()
                        }
                    }
                    QGCButton { text: "上传音频"; Layout.fillWidth: true; onClicked: filePicker.open() }
                    QGCButton { text: "一键警报"; Layout.fillWidth: true; onClicked: ShoutingManager.sendAlarm() }
                    QGCButton { text: "停止播放"; Layout.fillWidth: true; onClicked: ShoutingManager.stopPlayer() }
                }

                Item { Layout.fillHeight: true } // 弹簧，推到底部

                QGCButton {
                    text: "关闭面板"
                    Layout.fillWidth: true
                    onClicked: {
                        shoutingPanelShow = false
                        showFileList = false
                    }
                }
            }

            // ======================== 右侧：文件列表 (足够宽且动态出现) ========================
            Rectangle {
                id:                 fileListArea
                Layout.fillHeight:  true
                // 宽度由 states 里的 PropertyChanges 实时控制
                color:              Qt.rgba(0, 0, 0, 0.2)
                radius:             8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: "音频列表"; font.bold: true }
                        Item { Layout.fillWidth: true }
                        QGCButton {
                            text: "收起 >"
                            onClicked: shoutingTaskModule.showFileList = false // 🔹 实时触发回缩
                        }
                    }

                    // 分割线
                    Rectangle { Layout.fillWidth: true; height: 1; color: "white"; opacity: 0.1 }

                    ListView {
                        id:             fileListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model:          ShoutingManager.playList
                        spacing:        6
                        clip:           true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            width:  fileListView.width - 15
                            height: 40
                            color:  Qt.rgba(1, 1, 1, 0.08)
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10

                                QGCLabel {
                                    text: modelData.name.substring(modelData.name.lastIndexOf('/') + 1)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.pointSize: 9
                                }

                                QGCButton {
                                    text: "播放"
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 26
                                    onClicked: ShoutingManager.repeatPath(modelData.name)
                                }

                                QGCButton {
                                    text: "删除"
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 26
                                    onClicked: ShoutingManager.deleteMp3(modelData.name)
                                }
                            }
                        }
                    }

                    QGCLabel {
                        text: "暂无远程文件"
                        visible: fileListView.count === 0
                        Layout.alignment: Qt.AlignHCenter
                        color: "gray"
                    }
                }
            }
        }
    }
    // ============================================================
    // ★ 任务规划编辑面板（替换原有的 taskModule）
    // ============================================================
    PlanEditorPanel {
        id:                 _planEditor
        panelOpen:          taskPanelShow
        mapControl:         _root.mapControl
        z:                  QGroundControl.zOrderWidgets + 50
        onClosePanel:       taskPanelShow = false
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

        // B. 【任务规划面板开关】
        Rectangle {
            width: controlRow.btnSize; height: width; radius: width / 2
            color: taskPanelShow ? "#2266DD" : Qt.rgba(0.15, 0.15, 0.15, 0.7)
            visible:    toolsExpanded
            opacity:    toolsExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color   { ColorAnimation { duration: 150 } }

            QGCToolBarButton {
                anchors.centerIn: parent
                icon.source: "/qmlimages/Plan.svg"
                onClicked: {
                    taskPanelShow = !taskPanelShow
                    if (taskPanelShow) shoutingPanelShow = false
                }
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
        // Rectangle {
        //     width: controlRow.btnSize;
        //     height: width; radius: width / 2
        //     color: Qt.rgba(0.15, 0.15, 0.15, 0.7)
        //     visible:    toolsExpanded
        //     opacity:    toolsExpanded ? 1 : 0
        //     border.color: Qt.rgba(1, 0, 0, 0.3)
        //     Behavior on opacity { NumberAnimation { duration: 200 } }
        //
        //     QGCToolBarButton {
        //         anchors.centerIn: parent
        //         icon.source: "/res/GripperGrab.svg"
        //         onClicked: {
        //             if (globals.activeVehicle) {
        //                 globals.activeVehicle.sendCommand(
        //                     globals.activeVehicle.defaultComponentId,
        //                     MAVLink.MAV_CMD_DO_SET_SERVO,
        //                     true,
        //                     9, 2000
        //                 )
        //             }
        //         }
        //     }
        // }
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
