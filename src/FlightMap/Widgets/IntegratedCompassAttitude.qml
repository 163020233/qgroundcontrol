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
    // 整体放大 1.5 倍
    property real scaleFactor: 1.2

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

    IntegratedAttitudeIndicator {
        id:                     rollIndicator
        x:                      -_totalAttitudeSize
        attitudeAngleDegrees:   vehicle ? vehicle.roll.rawValue : 0
        compassRadius:          control.compassRadius
        attitudeSize:           control.attitudeSize * scaleFactor
        attitudeSpacing:        control.attitudeSpacing * scaleFactor
    }

    IntegratedAttitudeIndicator {
        x:                      -_totalAttitudeSize
        attitudeAngleDegrees:   vehicle ? vehicle.pitch.rawValue : 0
        compassRadius:          control.compassRadius
        attitudeSize:           control.attitudeSize * scaleFactor
        attitudeSpacing:        control.attitudeSpacing * scaleFactor
        transformOrigin:        Item.Center
        rotation:               90
    }

    Rectangle {
        y:      _totalAttitudeSize
        width:  compassRadius * 2
        height: width
        radius: width / 2
        color:  qgcPal.window
        // 透明度设置为 0.5，原来是 qgcPal.window 的颜色
        // color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.5)
        QGCCompassWidget {
            size:                       parent.width - compassBorder
            vehicle:                    control.vehicle
            usedByMultipleVehicleList:  control.usedByMultipleVehicleList
            anchors.centerIn:           parent
        }
    }
}
