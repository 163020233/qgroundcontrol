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
    property real _availableHeight:     availableHeight
    property real _availableWidth:      availableWidth

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
                    title:          qsTr("滚转比例增益 (MC_ROLL_P)")
                    description:    qsTr("增加以获得更多的响应速度，减少以避免姿态超调。")
                    param:          "MC_ROLL_P"
                    min:            1
                    max:            14
                    step:           0.5
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
                    title:          qsTr("俯仰比例增益 (MC_PITCH_P)")
                    description:    qsTr("增加以获得更多的响应速度，减少以避免姿态超调。")
                    param:          "MC_PITCH_P"
                    min:            1
                    max:            14
                    step:           0.5
                }
            }
        }
        property var yaw: QtObject {
            property string name: qsTr("偏航")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.heading.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.yaw.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("偏航比例增益 (MC_YAW_P)")
                    description:    qsTr("增加以获得更多的响应速度，减少以避免姿态超调 (当偏航固定时，只有一个设置点，即当摇杆居中时)。")
                    param:          "MC_YAW_P"
                    min:            1
                    max:            5
                    step:           0.1
                }
            }
        }
        title: "Attitude"
        tuningMode: Vehicle.ModeRateAndAttitude
        unit: "deg"
        axis: [ roll, pitch, yaw ]
        showAutoModeChange: true
        showAutoTuning:     true
    }
}

