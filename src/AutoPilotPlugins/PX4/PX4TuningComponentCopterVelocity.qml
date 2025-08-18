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
    property Fact _mcPosMode:       controller.getParameterFact(-1, "MPC_POS_MODE", false)

    GridLayout {
        columns: 2

        QGCLabel {
            text:               qsTr("位置控制模式 (调参过程中设置为 'simple'):")
            visible:            _mcPosMode
        }
        FactComboBox {
            fact:               _mcPosMode
            indexModel:         false
            visible:            _mcPosMode
        }
    }

    PIDTuning {
        id:                 pidTuning
        availableWidth:     _availableWidth
        availableHeight:    _availableHeight - pidTuning.y

        property var horizontal: QtObject {
            property string name: qsTr("水平")
            property string plotTitle: qsTr("水平 (Y 方向，侧面)")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.localPosition.vy.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.vy.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("水平比例增益 (MPC_XY_VEL_P_ACC)")
                    description:    qsTr("水平比例增益: 增加以提高响应速度，减少如果速率超调 (增加 D 没有帮助)。")
                    param:          "MPC_XY_VEL_P_ACC"
                    min:            1.2
                    max:            5
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("水平积分增益 (MPC_XY_VEL_I_ACC)")
                    description:    qsTr("水平积分增益: 增加以减少稳态误差 (例如风)")
                    param:          "MPC_XY_VEL_I_ACC"
                    min:            0.2
                    max:            10
                    step:           0.2
                }
                ListElement {
                    title:          qsTr("水平微分增益 (MPC_XY_VEL_D_ACC)")
                    description:    qsTr("水平微分增益: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "MPC_XY_VEL_D_ACC"
                    min:            0.1
                    max:            2
                    step:           0.05
                }
            }
        }
        property var vertical: QtObject {
            property string name: qsTr("垂直")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.localPosition.vz.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.vz.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("垂直比例增益 (MPC_Z_VEL_P_ACC)")
                    description:    qsTr("垂直比例增益: 增加以提高响应速度，减少如果速率超调 (增加 D 没有帮助)。")
                    param:          "MPC_Z_VEL_P_ACC"
                    min:            2
                    max:            15
                    step:           0.5
                }
                ListElement {
                    title:          qsTr("垂直积分增益 (MPC_Z_VEL_I_ACC)")
                    description:    qsTr("垂直积分增益: 增加以减少稳态误差")
                    param:          "MPC_Z_VEL_I_ACC"
                    min:            0.2
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("垂直微分增益 (MPC_Z_VEL_D_ACC)")
                    description:    qsTr("垂直微分增益: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "MPC_Z_VEL_D_ACC"
                    min:            0
                    max:            2
                    step:           0.05
                }
            }
        }
        title: "Velocity"
        tuningMode: Vehicle.ModeVelocityAndPosition
        unit: "m/s"
        axis: [ horizontal, vertical ]
    }
}


