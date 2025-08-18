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
            text:               qsTr("位置控制模式 (在调参过程中设置为 '简易'):")
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
                { name: "Response", value: globals.activeVehicle.localPosition.y.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.y.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("水平比例增益 (MPC_XY_P)")
                    description:    qsTr("增加以获得更多的响应速度，减少以避免位置超调 (当悬停时只有一个设置点，即当摇杆居中时)。")
                    param:          "MPC_XY_P"
                    min:            0
                    max:            2
                    step:           0.05
                }
            }
        }
        property var vertical: QtObject {
            property string name: qsTr("垂直")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.localPosition.z.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.z.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("垂直比例增益 (MPC_Z_P)")
                    description:    qsTr("增加以获得更多的响应速度，减少以避免位置超调 (当悬停时只有一个设置点，即当摇杆居中时)。")
                    param:          "MPC_Z_P"
                    min:            0
                    max:            2
                    step:           0.05
                }
            }
        }
        title: "Position"
        tuningMode: Vehicle.ModeVelocityAndPosition
        unit: "m"
        axis: [ horizontal, vertical ]
        chartDisplaySec: 50
    }
}


