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
                { name: "Response", value: globals.activeVehicle.rollRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.rollRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("滚转比例增益 (FW_RR_P)")
                    description:    qsTr("滚转比例增益.")
                    param:          "FW_RR_P"
                    min:            0.0
                    max:            1
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("滚转微分增益 (FW_RR_D)")
                    description:    qsTr("滚转微分增益: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "FW_RR_D"
                    min:            0.0
                    max:            1.0
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("滚转积分增益 (FW_RR_I)")
                    description:    qsTr("滚转积分增益: 增加以减少稳态误差 (例如风)")
                    param:          "FW_RR_I"
                    min:            0.0
                    max:            0.5
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("滚转前馈增益 (FW_RR_FF)")
                    description:    qsTr("滚转前馈增益: 增加以补偿空气阻力。")
                    param:          "FW_RR_FF"
                    min:            0.0
                    max:            10.0
                    step:           0.05
                }
            }
        }
        property var pitch: QtObject {
            property string name: qsTr("俯仰")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.pitchRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.pitchRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("俯仰比例增益 (FW_PR_P)")
                    description:    qsTr("俯仰比例增益.")
                    param:          "FW_PR_P"
                    min:            0.0
                    max:            1
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("俯仰微分增益 (FW_PR_D)")
                    description:    qsTr("俯仰微分增益: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "FW_PR_D"
                    min:            0.0
                    max:            1.00
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("俯仰积分增益 (FW_PR_I)")
                    description:    qsTr("俯仰积分增益: 增加以减少稳态误差 (例如风)")
                    param:          "FW_PR_I"
                    min:            0.0
                    max:            0.5
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("俯仰前馈增益 (FW_PR_FF)")
                    description:    qsTr("俯仰前馈增益: 增加以补偿空气阻力。")
                    param:          "FW_PR_FF"
                    min:            0.0
                    max:            10.0
                    step:           0.05
                }
            }
        }
        property var yaw: QtObject {
            property string name: qsTr("偏航")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.yawRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.yawRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("偏航比例增益 (FW_YR_P)")
                    description:    qsTr("偏航比例增益.")
                    param:          "FW_YR_P"
                    min:            0.0
                    max:            1
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("偏航微分增益 (FW_YR_D)")
                    description:    qsTr("偏航微分增益: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "FW_YR_D"
                    min:            0.0
                    max:            1.0
                    step:           0.005
                }
                ListElement {
                    title:          qsTr("偏航积分增益 (FW_YR_I)")
                    description:    qsTr("偏航积分增益: 增加以减少稳态误差 (例如风)")
                    param:          "FW_YR_I"
                    min:            0.0
                    max:            50.0
                    step:           0.5
                }
                ListElement {
                    title:          qsTr("偏航前馈增益 (FW_YR_FF)")
                    description:    qsTr("偏航前馈增益: 增加以补偿空气阻力。")
                    param:          "FW_YR_FF"
                    min:            0.0
                    max:            10.0
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("滚转到偏航前馈增益 (FW_RLL_TO_YAW_FF)")
                    description:    qsTr("用于抵消固定翼的逆偏航效果。")
                    param:          "FW_RLL_TO_YAW_FF"
                    min:            0.0
                    max:            1.0
                    step:           0.01
                }
            }
        }
        title: "Rate"
        tuningMode: Vehicle.ModeRateAndAttitude
        unit: "deg/s"
        axis: [ roll, pitch, yaw ]
        chartDisplaySec: 3
        showAutoModeChange: true
        showAutoTuning:     true
    }
}

