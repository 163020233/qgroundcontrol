/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Toolbar

//-------------------------------------------------------------------------
//-- Toolbar Indicators
Row {
    id:                 indicatorRow
    anchors.top:        parent.top
    anchors.bottom:     parent.bottom
    anchors.right:      parent.right

    anchors.margins:    _toolIndicatorMargins
    spacing:            ScreenTools.defaultFontPixelWidth * 1.85

    property var  _activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property real _toolIndicatorMargins:    ScreenTools.defaultFontPixelHeight * 0.64

    Repeater {
        id:     appRepeater
        model:  QGroundControl.corePlugin.toolBarIndicators
        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item.showIndicator
        }
    }

    Repeater {
        id:     toolIndicatorsRepeater
        model:  _activeVehicle ? _activeVehicle.toolIndicators : []

        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item.showIndicator
        }
    }

    Repeater {
        model: _activeVehicle ? _activeVehicle.modeIndicators : []
        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item.showIndicator
        }
    }

    // ========================================================
    // ★★★ 工业级定制：在这里插入你的“返回飞行主界面”图标 ★★★
    // ========================================================
    Item {
        id:                 homeButtonContainer
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom

        visible:            _activeVehicle && !mainWindow.isFlyView

        width:              visible ? (height + ScreenTools.defaultFontPixelWidth * 2) : 0

        // --- 分割线 (实现在图标左侧) ---
        Rectangle {
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            height:                 parent.height  // 线条高度为工具栏的 40%
            width:                  1
            color:                  "white"
            opacity:                0.2 // 半透明遮罩，显得高级
            visible:                parent.visible
        }

        // --- 图标内容 ---
        QGCColoredImage {
            anchors.centerIn:               parent
            anchors.horizontalCenterOffset: ScreenTools.defaultFontPixelWidth * 0.5
            width:                          parent.height
            height:                         width
            source:                         "/qmlimages/PaperPlane.svg"
            fillMode:                       Image.PreserveAspectFit
            // 关键：图标颜色绑定到主题文字颜色
            color:                          qgcPal.text
        }

        MouseArea {
            anchors.fill: parent
            onPressed:  homeIcon.opacity = 0.5
            onReleased: homeIcon.opacity = 1.0
            onClicked: {
                if (mainWindow.allowViewSwitch()) {
                    mainWindow.showFlyView()
                }
            }
        }
    }
}
