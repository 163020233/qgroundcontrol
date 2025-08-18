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

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.ScreenTools

Rectangle {
    color:          qgcPal.window
    anchors.fill:   parent

    readonly property real _margins: ScreenTools.defaultFontPixelHeight

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCFlickable {
        anchors.fill:   parent
        contentWidth:   column.width  + (_margins * 2)
        contentHeight:  column.height + (_margins * 2)
        clip:           true

        ColumnLayout {
            id:                 column
            anchors.margins:    _margins
            anchors.left:       parent.left
            anchors.top:        parent.top
            spacing:            ScreenTools.defaultFontPixelHeight

            QGCCheckBox {
                id:             sendStatusText
                text:           qsTr("发送状态文本 + 语音")
            }
            QGCButton {
                text:               qsTr("PX4 无人机")
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startPX4MockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("APM ArduCopter 无人机")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduCopterMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("APM ArduPlane 无人机")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduPlaneMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("APM ArduSub 无人机")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduSubMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("APM ArduRover 无人机")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduRoverMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("通用无人机")
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startGenericMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("停止模拟无人机")
                Layout.fillWidth:   true
                onClicked:          QGroundControl.stopOneMockLink()
            }
        }
    }
}
