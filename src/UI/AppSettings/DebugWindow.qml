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
import QtQuick.Window

import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.Controllers
import QGroundControl.ScreenTools

Item {

    Text {
        id:             _textMeasure
        text:           "X"
        color:          qgcPal.window
        font.family:    ScreenTools.normalFontFamily
    }

    GridLayout {
        anchors.margins: 20
        anchors.top:     parent.top
        anchors.left:    parent.left
        columns: 3
        Text {
            text:   qsTr("Qt 平台:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   Qt.platform.os
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 10")
            color:  qgcPal.text
            font.pointSize: 10
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("默认字体宽度:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   _textMeasure.contentWidth
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 10.5")
            color:  qgcPal.text
            font.pointSize: 10.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("默认字体高度:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   _textMeasure.contentHeight
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 11")
            color:  qgcPal.text
            font.pointSize: 11
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("默认字体像素大小:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   _textMeasure.font.pointSize
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 11.5")
            color:  qgcPal.text
            font.pointSize: 11.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("默认字体像素大小:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   _textMeasure.font.pointSize
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 12")
            color:  qgcPal.text
            font.pointSize: 12
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("QML 桌面可用宽度:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   Screen.desktopAvailableWidth + " x " + Screen.desktopAvailableHeight
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 12.5")
            color:  qgcPal.text
            font.pointSize: 12.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("QML 桌面可用宽度:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   Screen.width + " x " + Screen.height
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("字体点大小 13")
            color:  qgcPal.text
            font.pointSize: 13
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:   qsTr("QML 像素密度:")
            color:  qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           Screen.pixelDensity.toFixed(4)
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 13.5")
            color:          qgcPal.text
            font.pointSize: 13.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("QML 设备像素比:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           Screen.devicePixelRatio
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 14")
            color:          qgcPal.text
            font.pointSize: 14
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("默认字体点大小:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           ScreenTools.defaultFontPointSize
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 14.5")
            color:          qgcPal.text
            font.pointSize: 14.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("默认字体像素高度:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           ScreenTools.defaultFontPixelHeight
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 15")
            color:          qgcPal.text
            font.pointSize: 15
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("屏幕高度:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           (Screen.height / Screen.pixelDensity * Screen.devicePixelRatio).toFixed(0)
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 15.5")
            color:          qgcPal.text
            font.pointSize: 15.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("屏幕宽度:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           (Screen.width / Screen.pixelDensity * Screen.devicePixelRatio).toFixed(0)
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 16")
            color:          qgcPal.text
            font.pointSize: 16
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("屏幕可用宽度:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           Screen.desktopAvailableWidth
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 16.5")
            color:          qgcPal.text
            font.pointSize: 16.5
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("屏幕可用高度:")
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           Screen.desktopAvailableHeight
            color:          qgcPal.text
            font.family:    ScreenTools.normalFontFamily
        }
        Text {
            text:           qsTr("字体点大小 17")
            color:          qgcPal.text
            font.pointSize: 17
            font.family:    ScreenTools.normalFontFamily
        }
    }

    Rectangle {
        id:                 square
        width:              100
        height:             100
        color:              qgcPal.text
        anchors.right:      parent.right
        anchors.bottom:     parent.bottom
        anchors.margins:    10
        Text {
            text: "100x100"
            anchors.centerIn: parent
            color:  qgcPal.window
        }
    }

    Component.onCompleted: {
        for (var i = 10; i < 360; i = i + 60) {
            var colorValue = Qt.hsla(i/360, 0.85, 0.5, 1);
            seriesColors.push(colorValue)
            colorListModel.append({"colorValue": colorValue.toString()})
        }
    }

    property var seriesColors: []

    ListModel {
        id: colorListModel
    }

    Column {
        width:              100
        spacing:            0
        anchors.right:      square.left
        anchors.bottom:     parent.bottom
        anchors.margins:    10
        Repeater {
            model: colorListModel
            delegate: Rectangle {
                width:      100
                height:     100 / 6
                color:      colorValue
                Text {
                    text:   colorValue
                    color:  "#202020"
                    font.pointSize:     _textMeasure.font.pointSize * 0.75
                    anchors.centerIn:   parent
                }
            }
        }
    }

}
