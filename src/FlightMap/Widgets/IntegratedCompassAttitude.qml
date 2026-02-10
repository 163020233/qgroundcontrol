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
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap

Item {
    id:             control
    property real scaleFactor: 1.2 // 稍微缩小一点，显得更精致

    implicitWidth:  (compassRadius * 2) + attitudeSpacing + attitudeSize
    implicitHeight: implicitWidth

    property alias attitudeSize:                rollIndicator.attitudeSize
    property alias attitudeSpacing:             rollIndicator.attitudeSpacing
    property real extraInset:                   attitudeSize + attitudeSpacing
    property real extraValuesWidth:             compassRadius
    property real defaultCompassRadius:         (mainWindow.width * 0.15 / 2) * scaleFactor
    property real maxCompassRadius:             ScreenTools.defaultFontPixelHeight * 7 / 2 * scaleFactor
    property real compassRadius:                Math.min(defaultCompassRadius, maxCompassRadius)
    property real compassBorder:                ScreenTools.defaultFontPixelHeight / 2 * scaleFactor
    property var  vehicle:                      globals.activeVehicle
    property var  qgcPal:                       QGroundControl.globalPalette
    property bool usedByMultipleVehicleList:    false

    property real _totalAttitudeSize: attitudeSize + attitudeSpacing

    // --------------------------------------------------------
    // 1. 姿态指示器优化 (横滚)
    // --------------------------------------------------------
    IntegratedAttitudeIndicator {
        id:                     rollIndicator
        x:                      -_totalAttitudeSize
        attitudeAngleDegrees:   vehicle ? vehicle.roll.rawValue : 0
        compassRadius:          control.compassRadius
        attitudeSize:           control.attitudeSize * scaleFactor
        attitudeSpacing:        control.attitudeSpacing * scaleFactor
        // 降低亮度，实现 HUD 效果
        opacity:                0.8
    }

    // 2. 姿态指示器优化 (俯仰)
    IntegratedAttitudeIndicator {
        x:                      -_totalAttitudeSize
        attitudeAngleDegrees:   vehicle ? vehicle.pitch.rawValue : 0
        compassRadius:          control.compassRadius
        attitudeSize:           control.attitudeSize * scaleFactor
        attitudeSpacing:        control.attitudeSpacing * scaleFactor
        transformOrigin:        Item.Center
        rotation:               90
        opacity:                0.8
    }

    // --------------------------------------------------------
    // 3. 核心罗盘背景逻辑 (改为半透明玻璃质感)
    // --------------------------------------------------------
    Rectangle {
        y:      _totalAttitudeSize
        width:  compassRadius * 2
        height: width
        radius: width / 2

        // 【核心修改：去白增透】
        // 使用深黑色调 + 0.4 透明度
        color:  Qt.rgba(0, 0, 0, 0.4)

        // 增加一个淡淡的白边，定义出轮廓
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        QGCCompassWidget {
            size:                       parent.width - compassBorder
            vehicle:                    control.vehicle
            usedByMultipleVehicleList:  control.usedByMultipleVehicleList
            anchors.centerIn:           parent

            // 【核心修改：压制内部白度】
            // 让内部的罗盘刻度不再是刺眼的纯白，而是半透明灰白
            opacity: 0.7
        }
    }
}