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
    implicitWidth:  (compassRadius * 2) + attitudeSpacing + attitudeSize
    implicitHeight: implicitWidth -15  //  -15刚好能到底部·
    property alias attitudeSize:                rollIndicator.attitudeSize
    property alias attitudeSpacing:             rollIndicator.attitudeSpacing
    property real extraInset:                   attitudeSize + attitudeSpacing
    property real extraValuesWidth:             compassRadius
    property real defaultCompassRadius:         (mainWindow.width * 0.15) / 2  //占屏幕宽度的 15%默认罗盘半径: 决定了屏幕宽度的比例。
    property real maxCompassRadius:             ScreenTools.defaultFontPixelHeight * 12 / 2  //最大为 3.5 倍字体高度 (7/2)最大罗盘半径: 决定它的最大尺寸上限（
    property real compassRadius:                Math.min(defaultCompassRadius, maxCompassRadius)
    property real compassBorder:                ScreenTools.defaultFontPixelHeight / 2
    property var  vehicle:                      globals.activeVehicle
    property var  qgcPal:                       QGroundControl.globalPalette
    property bool usedByMultipleVehicleList:    false

    property real _totalAttitudeSize: attitudeSize + attitudeSpacing

    IntegratedAttitudeIndicator {
        id:                     rollIndicator
        x:                      -_totalAttitudeSize
        attitudeAngleDegrees:   vehicle ? vehicle.roll.rawValue : 0
        compassRadius:          control.compassRadius
    }

    IntegratedAttitudeIndicator {
        x:                      -_totalAttitudeSize
        attitudeAngleDegrees:   vehicle ? vehicle.pitch.rawValue : 0
        compassRadius:          control.compassRadius
        attitudeSize:           control.attitudeSize
        attitudeSpacing:        control.attitudeSpacing
        transformOrigin:        Item.Center
        rotation:               90
    }

    Rectangle {
        y:      _totalAttitudeSize
        width:  compassRadius * 2
        height: width
        radius: width / 2
        color:  qgcPal.window

        QGCCompassWidget {
            size:                       parent.width - compassBorder
            vehicle:                    control.vehicle
            usedByMultipleVehicleList:  control.usedByMultipleVehicleList
            anchors.centerIn:           parent
        }
    }
}
