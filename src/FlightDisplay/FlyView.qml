/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Vehicle

// 3D Viewer modules
import Viewer3D
import QtPositioning
Item {
    id: _root
    property var homePoint: null
    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMainStatusIndicatorTool() {
        toolbar.dropMainStatusIndicatorTool();
    }

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeBottomInset:    _pipView.leftEdgeBottomInset
        bottomEdgeLeftInset:    _pipView.bottomEdgeLeftInset
    }

    FlyViewToolBar {
        id:         toolbar
        visible:    !QGroundControl.videoManager.fullScreen
    }

    Component.onCompleted: {
        homeTimer.start()
    }

    Item {
        id:                 mapHolder
        anchors.top:        toolbar.bottom
        anchors.bottom:     parent.bottom
        anchors.left:       parent.left
        anchors.right:      parent.right
        // 控制展开状态
        property bool expanded: false

        FlyViewMap {
            id:                     mapControl
            planMasterController:   _planController
            rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
            pipView:                _pipView
            pipMode:                !_mainWindowIsMap
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen

        }

        // // 临时设置点位
        // Component.onCompleted: {
        //     _root.homePoint = QtPositioning.coordinate(30.813901,104.096312)
        //     mapControl.center = _root.homePoint
        //     mapControl.zoomLevel = 18
        // }


        // 主按钮（点击展开/收起）
        QGCToolBarButton {
            id: mainButton
            width: 48
            height: 48
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 16
            icon.source: "/res/buttonLeft.svg"
            visible: true
            z: 1000

            onClicked: {
                mapHolder.expanded = !mapHolder.expanded
                console.log("主按钮点击，expanded状态:", mapHolder.expanded)
            }
        }
        PositionSource {
            id: gcsPositionSource
            active: false   // 默认不启用
            updateInterval: 1000

            onPositionChanged: {
                // 先判断对象是否有效
                if (!position || !position.coordinate || !position.coordinate.isValid) {
                    console.log("GCS 定位信息无效或未准备好")
                    // 弹窗提醒用户
                    mainWindow.showMessageDialog(
                        qsTr("定位提示"),
                        qsTr("无法获取到 GCS 定位信息，请检查设备或权限"),
                        Dialog.Ok
                    )
                    return
                }

                if (!mapControl) {
                    console.log("地图控件未初始化")
                    return
                }

                // 安全设置中心点
                try {
                    mapControl.center = position.coordinate
                    mapControl.zoomLevel = 18
                    console.log("地图居中到 GCS 定位:", position.coordinate)
                } catch (e) {
                    console.log("设置 mapControl 失败:", e)
                    return
                }

                // 延迟停止
                Qt.callLater(() => {
                    if (gcsPositionSource && gcsPositionSource.active) {
                        gcsPositionSource.active = false
                        console.log("定位已停止")
                    }
                })
            }
        }


        // GCS 定位按钮
        QGCToolBarButton {
            id: gcsButton
            width: 48
            height: 48
            anchors.verticalCenter: mainButton.verticalCenter
            anchors.right: mainButton.right
            anchors.rightMargin: mapHolder.expanded ? 120 : 0

            icon.source: "/InstrumentValueIcons/home.svg"
            visible: mapHolder.expanded
            z: 1000

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            onClicked: {
                console.log("开始获取 GCS 定位...")
                gcsPositionSource.start()   // 点一次 → 开启定位
            }
        }
        // 飞控定位
        QGCToolBarButton {
            id: locateButton
            width: 48
            height: 48
            anchors.verticalCenter: mainButton.verticalCenter
            anchors.right: mainButton.right   // 默认和主按钮重合
            anchors.rightMargin: mapHolder.expanded ? 64 : 0 // 展开时右移，否则和主按钮重叠
            icon.source: "/res/waypoint.svg"
            visible: mapHolder.expanded       // 收起时隐藏
            z: 1000

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            onClicked: {
                if (activeVehicle && activeVehicle.coordinate.isValid) {
                    mapControl.center = activeVehicle.coordinate
                    mapControl.zoomLevel = 18
                    console.log("地图居中到飞行器位置:", activeVehicle.coordinate)
                } else {
                    console.log("飞行器位置未准备好")
                }
            }
        }

        // // 定位按钮，放右边中间
        // QGCToolBarButton {
        //     width: 48
        //     height: 48
        //     anchors.verticalCenter: parent.verticalCenter
        //     anchors.right: parent.right
        //     anchors.rightMargin: 16
        //     icon.source: "/res/locate.svg"
        //
        //     onClicked: {
        //         if (mapControl.gcsPosition && mapControl.gcsPosition.isValid) {
        //             mapControl.center = mapControl.gcsPosition
        //             mapControl.zoomLevel = 18
        //             console.log("地图居中到 GCS 位置")
        //         } else {
        //             console.log("GCS 位置未准备好")
        //         }
        //     }
        // }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
        }

        PipView {
            id:                     _pipView
            anchors.left:           parent.left
            anchors.bottom:         parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "MainFlyWindowIsMap"
            item1:                  mapControl
            item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
            show:                   QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins : 0
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            utmspActTrigger:        utmspSendActTrigger
            isViewer3DOpen:         viewer3DWindow.isOpen
        }

        FlyViewCustomLayer {
            id:                 customOverlay
            anchors.fill:       widgetLayer
            z:                  _fullItemZorder + 2
            parentToolInsets:   widgetLayer.totalToolInsets
            mapControl:         _mapControl
            visible:            !QGroundControl.videoManager.fullScreen
        }

        // Development tool for visualizing the insets for a paticular layer, show if needed
        FlyViewInsetViewer {
            id:                     widgetLayerInsetViewer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            z:                  QGroundControl.zOrderTopMost
            visible:            false
        }

        Viewer3D{
            id:                     viewer3DWindow
            anchors.fill:           parent
        }
    }
}
