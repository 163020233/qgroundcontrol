/****************************************************************************
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Toolbar
import QGroundControl.Palette

//-------------------------------------------------------------------------
//-- Toolbar Indicators
Row {
    id:                 indicatorRow
    // ★ 保留源码的锚点逻辑：靠右对齐
    anchors.top:        parent.top
    anchors.bottom:     parent.bottom
    anchors.right:      parent.right

    anchors.margins:    _toolIndicatorMargins
    spacing:            ScreenTools.defaultFontPixelWidth * 1.85

    property var  _activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property real _toolIndicatorMargins:    ScreenTools.defaultFontPixelHeight * 0.64

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // 1. App Indicators
    Repeater {
        id:     appRepeater
        model:  QGroundControl.corePlugin.toolBarIndicators
        Loader {
            // ★ 核心修复：禁止使用 anchors，改为直接设置高度
            height:             parent.height
            source:             modelData
            // 恢复显隐逻辑
            visible:            item && item.showIndicator
        }
    }

    // 2. Vehicle Indicators
    Repeater {
        id:     toolIndicatorsRepeater
        model:  _activeVehicle ? _activeVehicle.toolIndicators : []
        Loader {
            height:             parent.height
            source:             modelData
            visible:            item && item.showIndicator
        }
    }

    // 3. Mode Indicators
    Repeater {
        model: _activeVehicle ? _activeVehicle.modeIndicators : []
        Loader {
            height:             parent.height
            source:             modelData
            visible:            item && item.showIndicator
        }
    }

    // ========================================================
    // ★★★ 你的自定义返回图标 (保持在这个 Row 的最末尾) ★★★
    // ========================================================
    Item {
        id:                 homeButtonContainer
        // ★ 核心修复：禁止使用 anchors，改为直接设置高度
        height:             parent.height

        visible:            _activeVehicle && planView.visible
        // 动态宽度：不显示时不占位
        width:              visible ? (height + ScreenTools.defaultFontPixelWidth * 2) : 0

        // --- 分割线 ---
        Rectangle {
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            height:                 parent.height
            width:                  1
            color:                  qgcPal.text
            opacity:                0.2
            visible:                parent.visible
        }

        // --- 图标 ---
        QGCColoredImage {
            id:                             homeIcon
            anchors.centerIn:               parent
            anchors.horizontalCenterOffset: ScreenTools.defaultFontPixelWidth * 0.5
            width:                          parent.height
            height:                         width
            source:                         "/qmlimages/PaperPlane.svg"
            fillMode:                       Image.PreserveAspectFit
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