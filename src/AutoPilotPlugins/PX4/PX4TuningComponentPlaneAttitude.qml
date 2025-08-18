/****************************************************************************
 *
 * (c) 2021 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.ScreenTools
import QGroundControl.Vehicle

ColumnLayout {
    property real _availableHeight: availableHeight
    property real _availableWidth:  availableWidth

    PIDTuning {
        id:                 pidTuning
        availableWidth:     _availableWidth
        availableHeight:    _availableHeight - pidTuning.y

        property var roll: QtObject {
            property string name: qsTr("滚转")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.roll.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.roll.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("滚转时间常数 (FW_R_TC)")
                    description:    qsTr("滚转时间常数: 滚转输入与 achieved setpoint 之间的延迟 (与 P 增益成反比)")
                    param:          "FW_R_TC"
                    min:            0.4
                    max:            1.0
                    step:           0.05
                }
            }
        }
        property var pitch: QtObject {
            property string name: qsTr("俯仰")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.pitch.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.pitch.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("俯仰时间常数 (FW_P_TC)")
                    description:    qsTr("俯仰时间常数: 俯仰输入与 achieved setpoint 之间的延迟 (与 P 增益成反比)")
                    param:          "FW_P_TC"
                    min:            0.2
                    max:            1.0
                    step:           0.05
                }
            }
        }
        title: "Attitude"
        tuningMode: Vehicle.ModeRateAndAttitude
        unit: "deg"
        axis: [ roll, pitch ]
        showAutoModeChange: true
        showAutoTuning:     true
    }
}
