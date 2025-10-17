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
import QGroundControl.Vehicle
import QGroundControl.Palette

Canvas {
    id:                 control
    anchors.centerIn:   parent
    width:              compassSize * 1/3
    height:             width

    property real compassSize
    property real heading
    property bool simplified:    false

    property var _qgcPal: QGroundControl.globalPalette

    Connections {
        target:                 _qgcPal
        onGlobalThemeChanged:   control.requestPaint()
    }

    onPaint: {
        var ctx = getContext("2d")

        // 根据 simplified 决定颜色，这里改成蓝色
        ctx.strokeStyle = simplified ? "#3498db" : _qgcPal.text  // 文字颜色保持不变
        ctx.fillStyle = "#3498db"                                 // 蓝色填充
        ctx.lineWidth = 1

        ctx.beginPath()
        ctx.moveTo(width / 2, 0)
        ctx.lineTo(width, height)
        ctx.lineTo(width / 2, height * 0.75)
        ctx.lineTo(width / 2, 0)
        ctx.fill()
        ctx.stroke()

        // 第二个箭头也改为深蓝色
        ctx.fillStyle = "#2980b9"
        ctx.beginPath()
        ctx.moveTo(width / 2, 0)
        ctx.lineTo(0, height)
        ctx.lineTo(width / 2, height * 0.75)
        ctx.lineTo(width / 2, 0)
        ctx.fill()
        ctx.stroke()
    }

    transform: Rotation {
        origin.x:   control.width / 2
        origin.y:   control.height / 2
        angle:      heading
    }
}
