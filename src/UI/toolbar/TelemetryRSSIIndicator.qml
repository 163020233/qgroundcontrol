/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette

//-------------------------------------------------------------------------
//-- Telemetry RSSI
Item {
    id:             control
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          telemIcon.width * 1.1

    property bool showIndicator: _hasTelemetry

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property bool _hasTelemetry:    _activeVehicle.telemetryLRSSI !== 0

    QGCColoredImage {
        id:                 telemIcon
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        width:              height
        sourceSize.height:  height
        source:             "/qmlimages/TelemRSSI.svg"
        fillMode:           Image.PreserveAspectFit
        color:              qgcPal.buttonText
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(telemRSSIInfoPage, control)
    }

    Component {
        id: telemRSSIInfoPage

        ToolIndicatorPage {
            showExpand: false

            contentComponent: SettingsGroupLayout {
                heading: qsTr("遥测 RSSI 状态")

                LabelledLabel {
                    label:      qsTr("本地 RSSI:")
                    labelText:  _activeVehicle.telemetryLRSSI + " " + qsTr("dBm")
                }

                LabelledLabel {
                    label:      qsTr("远程 RSSI:")
                    labelText:  _activeVehicle.telemetryRRSSI + " " + qsTr("dBm")
                }

                LabelledLabel {
                    label:      qsTr("接收错误:")
                    labelText:  _activeVehicle.telemetryRXErrors
                }

                LabelledLabel {
                    label:      qsTr("错误修复:")
                    labelText:  _activeVehicle.telemetryFixed
                }

                LabelledLabel {
                    label:      qsTr("TX 缓冲区:")
                    labelText:  _activeVehicle.telemetryTXBuffer
                }

                LabelledLabel {
                    label:      qsTr("本地噪声:")
                    labelText:  _activeVehicle.telemetryLNoise
                }

                LabelledLabel {
                    label:      qsTr("远程噪声:")
                    labelText:  _activeVehicle.telemetryRNoise
                }
            }
        }
    }
}
