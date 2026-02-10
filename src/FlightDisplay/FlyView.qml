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

        // --- 新增这一行，告诉系统顶部有顶栏高度的缩进 ---
        topEdgeCenterInset:     toolbartoolbar.height
    }

    // src/FlightDisplay/FlyView.qml

    FlyViewToolBar {
        id:         toolbar
        z:          1000
        anchors.left:  parent.left
        anchors.right: parent.right

        // --- 【核心动画逻辑：向上滑出 + 淡出】 ---
        anchors.top:   parent.top

        // 逻辑：当面板打开时，间距变为负的高度，使其“藏”到屏幕上方
        anchors.topMargin: (toolDrawer.visible || QGroundControl.videoManager.fullScreen) ? -height : 0

        // 透明度随位置同步变化
        opacity:           (toolDrawer.visible || QGroundControl.videoManager.fullScreen) ? 0 : 1

        // 只有在没完全滑出时才占用点击事件
        visible:           opacity > 0

        // 定义平滑的过渡动画
        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 500 // 增加时长，降低速度
                easing.type: Easing.OutQuad // 使用平滑曲线
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 500 }
        }
        // --------------------------------------
    }

    Component.onCompleted: {
        homeTimer.start()
    }

    Item {
        id:                 mapHolder
        // 修改这里：不要对齐到 toolbar.bottom，要直接对齐到 parent.top
        anchors.top:        parent.top   // 地图顶点直到屏幕最上方
        anchors.bottom:     parent.bottom
        anchors.left:       parent.left
        anchors.right:      parent.right



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


        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
        }

        // 视频 ↔ 地图”切换的核心实现
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
            // 1. 恢复到 parent.top，保证它能撑开高度
            anchors.top:            parent.top

            // 2. 【核心优化】使用边距把图标挤下去
            // 这样背景依然是全屏的，但内部图标的起点变成了顶栏下方
            anchors.topMargin:      toolbar.height

            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right

            // 确保 Z 轴足够高，能看到图标
            z:                      _fullItemZorder + 2
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            utmspActTrigger:        utmspSendActTrigger
            isViewer3DOpen:         viewer3DWindow.isOpen
        }

        FlyViewCustomLayer {
            id:                 customOverlay

            // --- 【核心修改】 ---
            // 不要填充 widgetLayer，改为填充 parent (即整个 FlyView)
            // 这样无论左边怎么变，你的这个层都是全屏不动的
            anchors.fill:       parent

            // 确保它依然在 UI 层级之上
            z:                  widgetLayer.z + 1

            // 依然要把 widgetLayer 的 Insets 传进去
            // 这样你内部的按钮依然可以知道左边被占用了多少像素
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
            Component.onCompleted: {
                // 强制让解锁、上锁、降落等动作，都使用你自定义的 GuidedActionConfirm
                guidedActionsController.confirmDialog = widgetLayer.findChild("GuidedActionConfirm")
                // 或者直接通过 ID 绑定
            }
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.bottom
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
