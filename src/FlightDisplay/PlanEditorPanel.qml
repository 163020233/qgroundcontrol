/****************************************************************************
 *
 * PlanEditorPanel.qml — 左右分离：左侧操作栏 + 右侧编辑面板
 *
 * 左侧：固定在左边缘，title / 操作按钮 / Tab / [+] 按钮
 * 右侧：贴在屏幕右边缘，显示航点列表或围栏编辑
 *
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

Item {
    id: _root

    property bool panelOpen: false
    signal closePanel()
    property var mapControl
    property bool addWaypointMode: false

    readonly property var _planMasterController:  globals.planMasterControllerFlyView
    readonly property var _missionController:     _planMasterController ? _planMasterController.missionController : null
    readonly property var _geoFenceController:    _planMasterController ? _planMasterController.geoFenceController : null
    readonly property var _visualItems:           _missionController ? _missionController.visualItems : null

    readonly property int _layerMission:  1
    readonly property int _layerGeoFence: 2
    property int _currentLayer: _layerMission
    property bool _rightPanelActive: false

    readonly property real _margin:      ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real _btnHeight:   ScreenTools.defaultFontPixelHeight * 2

    anchors.fill: parent

    // 左侧操作栏
    Rectangle {
        id:                     _leftBar
        anchors.top:            parent.top
        anchors.topMargin:      ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight * 3.9
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 9
        anchors.left:           parent.left

        width:                  ScreenTools.defaultFontPixelWidth * 20
        color:                  Qt.rgba(0.08, 0.08, 0.08, 0.7)
        z:                      QGroundControl.zOrderWidgets + 40

        anchors.leftMargin:     panelOpen ? 0 : -width - 20

        Behavior on anchors.leftMargin {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }

        clip: true

        ColumnLayout {
            anchors.fill:       parent
            anchors.margins:    _margin
            spacing:            _margin * 0.6

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text: qsTr("任务规划"); font.pointSize: ScreenTools.mediumFontPointSize * 1; font.bold: true
                    color: "white"; Layout.alignment: Qt.AlignLeft
                }
                Item { Layout.fillWidth: true }
                QGCButton {
                    text: "✕"; font.bold: true; width: _btnHeight * 1.2; height: _btnHeight * 1.2
                    Layout.alignment: Qt.AlignRight; onClicked: _root.closePanel()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: _margin * 0.3
                QGCButton { text: qsTr("上传"); Layout.fillWidth: true
                    enabled: _planMasterController && !_planMasterController.offline && !_planMasterController.syncInProgress && _planMasterController.containsItems
                    visible: !QGroundControl.corePlugin.options.disableVehicleConnection
                    onClicked: _planMasterController.upload()
                    leftPadding: 4; rightPadding: 4
                }
                QGCButton { text: qsTr("下载"); Layout.fillWidth: true
                    enabled: _planMasterController && !_planMasterController.offline && !_planMasterController.syncInProgress
                    visible: !QGroundControl.corePlugin.options.disableVehicleConnection
                    onClicked: _planMasterController.loadFromVehicle()
                    leftPadding: 4; rightPadding: 4
                }
                QGCButton { text: qsTr("保存"); Layout.fillWidth: true
                    enabled: _planMasterController && !_planMasterController.syncInProgress && _planMasterController.containsItems
                    onClicked: _planMasterController.saveToSelectedFile()
                    leftPadding: 4; rightPadding: 4
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.1) }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Rectangle {
                    Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 2.2; radius: 4
                    color: _currentLayer == _layerMission ? Qt.rgba(0.3,0.5,0.8,0.6) : Qt.rgba(1,1,1,0.08)
                    QGCLabel { anchors.centerIn: parent; text: qsTr("任务"); color: "white"; font.pointSize: ScreenTools.smallFontPointSize }
                    QGCMouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { _currentLayer = _layerMission; _rightPanelActive = true } }
                }
                Rectangle {
                    Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 2.2; radius: 4
                    color: _currentLayer == _layerGeoFence ? Qt.rgba(0.3,0.5,0.8,0.6) : Qt.rgba(1,1,1,0.08)
                    visible: _geoFenceController ? _geoFenceController.supported : false
                    QGCLabel { anchors.centerIn: parent; text: qsTr("围栏"); color: "white"; font.pointSize: ScreenTools.smallFontPointSize }
                    QGCMouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { _currentLayer = _layerGeoFence; _rightPanelActive = true } }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: ScreenTools.defaultFontPixelHeight * 2; height: width; radius: width / 2
                color: _addMouseArea.containsMouse ? "#3388FF" : "#2266DD"
                border.color: Qt.rgba(1,1,1,0.3); border.width: 2
                visible: _currentLayer == _layerMission
                Behavior on color { ColorAnimation { duration: 120 } }
                QGCLabel { anchors.centerIn: parent; text: "+"; font.pointSize: ScreenTools.largeFontPointSize * 1.3; font.bold: true; color: "white" }
                QGCMouseArea {
                    id: _addMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        _currentLayer = _layerMission
                        _rightPanelActive = true
                        _root.addWaypointMode = !_root.addWaypointMode
                    }
                }
            }
        }
    }

    // 右侧编辑面板
    Rectangle {
        id:                     _rightPanel
        anchors.top:            parent.top
        anchors.topMargin:      ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight * 3.9
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 9
        anchors.right:          parent.right

        width:                  Math.min(parent.width * 0.25, ScreenTools.defaultFontPixelWidth * 26)
        color:                  Qt.rgba(0.08, 0.08, 0.08, 0.7)
        z:                      QGroundControl.zOrderWidgets + 40

        clip:                   true

        anchors.rightMargin:    (panelOpen && _rightPanelActive) ? 0 : -width - 20

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }

        // ✕ 关闭按钮
        Rectangle {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: _margin * 0.3; anchors.rightMargin: _margin * 0.3
            width: _btnHeight * 0.7; height: width; radius: width / 2
            color: Qt.rgba(1,1,1,0.1); z: 10
            QGCLabel { anchors.centerIn: parent; text: "✕"; color: "white"; font.pointSize: ScreenTools.smallFontPointSize }
            QGCMouseArea { anchors.fill: parent; onClicked: _rightPanelActive = false }
        }

        // 内容区
        Item {
            anchors.fill:       parent
            anchors.margins:    _margin * 0.8
            clip:               true

            Item {
                anchors.fill: parent
                visible: _currentLayer == _layerMission

                QGCListView {
                    id:                 _missionListView
                    anchors.fill:       parent
                    spacing:            ScreenTools.defaultFontPixelHeight / 4
                    orientation:        ListView.Vertical
                    model:              _visualItems
                    cacheBuffer:        Math.max(height * 2, 0)
                    clip:               true
                    currentIndex:       _missionController ? _missionController.currentPlanViewSeqNum : 0
                    highlightMoveDuration: 250

                    delegate: MissionItemEditor {
                        map:                _root.mapControl
                        masterController:   _planMasterController
                        missionItem:        object
                        width:              _missionListView.width
                        readOnly:           false
                        onClicked: (seqNum) => {
                            if (_missionController) {
                                if (object.isCurrentItem) {
                                    _missionController.setCurrentPlanViewSeqNum(-1, true)
                                } else {
                                    _missionController.setCurrentPlanViewSeqNum(object.sequenceNumber, false)
                                }
                            }
                        }
                        onRemove: {
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

            Item {
                anchors.fill: parent
                visible: _currentLayer == _layerGeoFence

                GeoFenceEditor {
                    anchors.fill: parent
                    myGeoFenceController: _geoFenceController
                    flightMap: _root.mapControl
                }
            }
        }
    }
}
