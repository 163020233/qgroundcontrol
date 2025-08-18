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

        property var data: QtObject {
            property string name: qsTr("高度 & 对气速度")
            property var plot: [
                { name: "对气速度", value: globals.activeVehicle.airSpeed.value },
                { name: "对气速度设置点", value: globals.activeVehicle.airSpeedSetpoint.value },
                { name: "高度 (相对)", value: globals.activeVehicle.altitudeTuning.value },
                { name: "高度设置点", value: globals.activeVehicle.altitudeTuningSetpoint.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("高度速率前馈增益 (FW_T_HRATE_FF)")
                    description:    qsTr("高度速率前馈增益: 增加以补偿空气阻力。")
                    param:          "FW_T_HRATE_FF"
                    min:            0
                    max:            1
                    step:           0.05
                }
            }
            // TODO: add other params
        }
        title: "TECS"
        tuningMode: Vehicle.ModeAltitudeAndAirspeed
        unit: ""
        axis: [ data ]
    }
}



