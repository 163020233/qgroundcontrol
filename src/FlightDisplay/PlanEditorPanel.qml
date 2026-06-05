/****************************************************************************
 *
 * PlanEditorPanel.qml
 * 独立的任务编辑面板 — 嵌入 FlyView 左侧，替代 PlanView
 *
 * 架构层次：
 *   ┌────────────────────────────────────────────────┐
 *   │  PlanEditorPanel (QML 容器)                    │
 *   │  ├─ 标题栏 (标题 + 关闭按钮)                   │
 *   │  ├─ 操作栏 (上传 / 下载 / 保存)                │
 *   │  ├─ TabBar (任务 / 围栏 / 高程)                │
 *   │  ├─ 编辑区 (按 Tab 切换)                       │
 *   │  │   ├─ MissionEditor → 航点列表 + 参数编辑     │
 *   │  │   ├─ GeoFenceEditor                        │
 *   │  │   └─ RallyPointEditor                      │
 *   │  └─ 底部 [+] 添加航点按钮                      │
 *   └────────────────────────────────────────────────┘
 *
 *  依赖：通过 globals.planMasterControllerFlyView 获取
 *        FlyView 的 PlanMasterController (flyView: true)
 *
 *  (c) 2024-2025
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.Controllers
import QGroundControl.FlightMap
import QGroundControl.FlightDisplay

Rectangle {
    id: _root

    // ============================================================
    // 对外接口属性
    // ============================================================

    /// 面板是否打开（控制滑出动画）
    property bool panelOpen: false

    /// 请求关闭面板的信号（由父级处理，避免绑定断裂）
    signal closePanel()

    /// 地图控件引用（由 FlyViewCustomLayer 注入）
    property var mapControl

    /// 是否启用地图点击添加航点模式（由外部控制）
    property bool addWaypointMode: false

    // ============================================================
    // 内部引用
    // ============================================================

    QtObject {
        id: _private

        // 通过 MainWindow 的 globals 拿到 FlyView 的 PlanMasterController
        readonly property var planMasterController: globals.planMasterControllerFlyView
        readonly property var missionController:    planMasterController ? planMasterController.missionController : null
        readonly property var geoFenceController:   planMasterController ? planMasterController.geoFenceController : null
        readonly property var rallyPointController: planMasterController ? planMasterController.rallyPointController : null
        readonly property var visualItems:          missionController ? missionController.visualItems : null
        readonly property var activeVehicle:        QGroundControl.multiVehicleManager.activeVehicle
    }

    // ============================================================
    // 编辑层枚举
    // ============================================================

    readonly property int _layerMission:  1
    readonly property int _layerGeoFence: 2
    readonly property int _layerRally:    3

    property int _currentLayer: _layerMission

    // ============================================================
    // UI 常量
    // ============================================================

    readonly property real _margin:         ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real _toolsMargin:    ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real _btnHeight:      ScreenTools.defaultFontPixelHeight * 2.4

    // ============================================================
    // 面板尺寸与动画
    // ============================================================

    anchors.top:        parent.top
    anchors.bottom:     parent.bottom
    anchors.left:       parent.left
    anchors.topMargin:  ScreenTools.toolbarHeight

    width:              panelOpen ? _panelWidth : 0
    readonly property real _panelWidth: Math.min(parent.width * 0.32, ScreenTools.defaultFontPixelWidth * 32)

    color:              Qt.rgba(0.08, 0.08, 0.08, 0.93)
    radius:             0
    z:                  QGroundControl.zOrderWidgets + 40

    Behavior on width {
        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
    }

    clip: true

    // ============================================================
    // 面板内容（宽度为 0 时不渲染提升性能）
    // ============================================================

    ColumnLayout {
        anchors.fill:           parent
        anchors.margins:        _margin * 1.5
        spacing:                _margin * 0.8
        visible:                width > 0

        // ---------- 标题栏 ----------
        RowLayout {
            Layout.fillWidth:   true

            QGCLabel {
                text:               qsTr("任务规划")
                font.pointSize:     ScreenTools.mediumFontPointSize
                font.bold:          true
                color:              "white"
                Layout.alignment:   Qt.AlignLeft
            }

            Item { Layout.fillWidth: true }

            QGCButton {
                text:               qsTr("✕")
                font.bold:          true
                width:              _btnHeight
                height:             _btnHeight
                Layout.alignment:   Qt.AlignRight
                onClicked:          _root.closePanel()
            }
        }

        // ---------- 操作栏（上传 / 下载 / 保存） ----------
        RowLayout {
            Layout.fillWidth:       true
            spacing:                _margin * 0.5

            QGCButton {
                text:               qsTr("上传")
                Layout.fillWidth:   true
                enabled:            _private.planMasterController && !_private.planMasterController.offline && !_private.planMasterController.syncInProgress && _private.planMasterController.containsItems
                visible:            !QGroundControl.corePlugin.options.disableVehicleConnection
                onClicked:          _private.planMasterController.upload()
            }

            QGCButton {
                text:               qsTr("下载")
                Layout.fillWidth:   true
                enabled:            _private.planMasterController && !_private.planMasterController.offline && !_private.planMasterController.syncInProgress
                visible:            !QGroundControl.corePlugin.options.disableVehicleConnection
                onClicked:          _private.planMasterController.loadFromVehicle()
            }

            QGCButton {
                text:               qsTr("保存")
                Layout.fillWidth:   true
                enabled:            _private.planMasterController && !_private.planMasterController.syncInProgress && _private.planMasterController.containsItems
                onClicked:          _private.planMasterController.saveToSelectedFile()
            }
        }

        Rectangle {
            Layout.fillWidth:   true
            height:              1
            color:              Qt.rgba(1, 1, 1, 0.1)
        }

        // ---------- TabBar ----------
        QGCTabBar {
            id:                     layerTabBar
            Layout.fillWidth:       true
            Component.onCompleted:  currentIndex = 0

            onCurrentIndexChanged: {
                switch (currentIndex) {
                    case 0: _currentLayer = _layerMission;  break
                    case 1: _currentLayer = _layerGeoFence; break
                    case 2: _currentLayer = _layerRally;    break
                }
            }

            QGCTabButton { text: qsTr("任务") }
            QGCTabButton { text: qsTr("围栏"); enabled: _private.geoFenceController ? _private.geoFenceController.supported : false }
            QGCTabButton { text: qsTr("集合点"); enabled: _private.rallyPointController ? true : false }
        }

        // ---------- 编辑区 ----------
        // 任务编辑（航点列表）
        Item {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            _currentLayer == _layerMission

            QGCListView {
                id:                 _missionListView
                anchors.fill:       parent
                spacing:            ScreenTools.defaultFontPixelHeight / 4
                orientation:        ListView.Vertical
                model:              _private.visualItems
                cacheBuffer:        Math.max(height * 2, 0)
                clip:               true
                currentIndex:       _private.missionController ? _private.missionController.currentPlanViewSeqNum : 0
                highlightMoveDuration: 250

                delegate: MissionItemEditor {
                    map:                _root.mapControl
                    masterController:   _private.planMasterController
                    missionItem:        object
                    width:              _missionListView.width
                    readOnly:           false
                    onClicked: (seqNum) => {
                        if (_missionController) {
                            // 如果点击的是当前已选中的项，收起编辑器（-1 不存在任何项，全部收起）
                            if (object.isCurrentItem) {
                                _missionController.setCurrentPlanViewSeqNum(-1, true)
                            } else {
                                _missionController.setCurrentPlanViewSeqNum(object.sequenceNumber, false)
                            }
                        }
                    }
                    onRemove: {
                        // 启动任务不可删除
                        if (object && object.sequenceNumber === 0) return
                        Qt.callLater(function() {
                            if (_missionController) {
                                _missionController.removeVisualItem(index)
                            }
                        })
                    }
                }
            }
        }

        // 围栏编辑器
        Item {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            _currentLayer == _layerGeoFence

            GeoFenceEditor {
                anchors.fill:           parent
                myGeoFenceController:   _private.geoFenceController
                flightMap:              _root.mapControl
            }
        }

        // 集合点编辑器
        Item {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            _currentLayer == _layerRally

            ColumnLayout {
                anchors.fill:       parent
                spacing:            _margin

                RallyPointEditorHeader {
                    Layout.fillWidth:   true
                    controller:         _private.rallyPointController
                }
                RallyPointItemEditor {
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    visible:            _private.rallyPointController && _private.rallyPointController.points.count
                    rallyPoint:         _private.rallyPointController ? _private.rallyPointController.currentRallyPoint : null
                    controller:         _private.rallyPointController
                }
            }
        }

        // ---------- 底部 [+] 添加航点按钮 ----------
        Item {
            Layout.fillWidth:   true
            height:             _addBtn.height + _margin

            Rectangle {
                id:                 _addBtn
                anchors.centerIn:   parent
                width:              ScreenTools.defaultFontPixelHeight * 3
                height:             width
                radius:             width / 2
                color:              _addMouseArea.containsMouse ? "#3388FF" : "#2266DD"
                border.color:       Qt.rgba(1, 1, 1, 0.3)
                border.width:       2
                visible:            _currentLayer == _layerMission

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               "+"
                    font.pointSize:     ScreenTools.largeFontPointSize * 1.3
                    font.bold:          true
                    color:              "white"
                }

                QGCMouseArea {
                    id:                 _addMouseArea
                    anchors.fill:       parent
                    hoverEnabled:       true
                    cursorShape:        Qt.PointingHandCursor
                    onClicked: {
                        // 通知外部进入"添加航点模式"——下次点击地图时插入
                        _root.addWaypointMode = !_root.addWaypointMode
                    }
                }
            }
        }
    }

    // ============================================================
    // 面板打开/关闭信号
    // ============================================================

    signal panelOpened()
    signal panelClosed()

    onPanelOpenChanged: {
        if (panelOpen) panelOpened()
        else panelClosed()
    }
}
