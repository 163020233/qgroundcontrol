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
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Palette

ColumnLayout {
    id:         root
    spacing:    ScreenTools.defaultFontPixelWidth * 0.5

    property var    map
    property var    fitFunctions
    property bool   showMission:          true
    property bool   showAllItems:         true

    QGCLabel { text: qsTr("居中地图于:") }

    QGCButton {
        text:               qsTr("任务")
        Layout.fillWidth:   true
        visible:            showMission

        onClicked: {
            dropPanel.hide()
            fitFunctions.fitMapViewportToMissionItems()
        }
    }

    QGCButton {
        text:               qsTr("所有项目")
        Layout.fillWidth:   true
        visible:            showAllItems

        onClicked: {
            dropPanel.hide()
            fitFunctions.fitMapViewportToAllItems()
        }
    }

    QGCButton {
        text:               qsTr("发射")
        Layout.fillWidth:   true

        onClicked: {
            dropPanel.hide()
            map.center = fitFunctions.fitHomePosition()
        }
    }

    QGCButton {
        text:               qsTr("设备")
        Layout.fillWidth:   true
        enabled:            globals.activeVehicle && globals.activeVehicle.coordinate.isValid

        onClicked: {
            dropPanel.hide()
            map.center = globals.activeVehicle.coordinate
        }
    }

    QGCButton {
        text:               qsTr("当前位置")
        Layout.fillWidth:   true
        enabled:            map.gcsPosition.isValid

        onClicked: {
            dropPanel.hide()
            map.center = map.gcsPosition
        }
    }

    QGCButton {
        text:               qsTr("指定位置")
        Layout.fillWidth:   true

        onClicked: {
            dropPanel.hide()
            map.centerToSpecifiedLocation()
        }
    }
} // Column
