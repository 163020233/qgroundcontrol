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
    property Fact _airmode:             controller.getParameterFact(-1, "MC_AIRMODE", false)
    property Fact _thrustModelFactor:   controller.getParameterFact(-1, "THR_MDL_FAC", false)

    RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCLabel {
            textFormat:         Text.RichText
            text:               qsTr("航空模式 (在调参过程中禁用) <b><a href=\"https://docs.px4.io/main/en/config_mc/pid_tuning_guide_multicopter.html#airmode-mixer-saturation\">?</a></b>")
            onLinkActivated:    (link) => Qt.openUrlExternally(link)
            visible:            _airmode
        }
        FactComboBox {
            fact:               _airmode
            indexModel:         false
            visible:            _airmode
        }

        Item {
            width: 1
            height: 1
        }

        QGCLabel {
            textFormat:         Text.RichText
            text:               qsTr("推力曲线 <b><a href=\"https://docs.px4.io/main/en/config_mc/pid_tuning_guide_multicopter.html#thrust-curve\">?</a></b>")
            onLinkActivated:    (link) => Qt.openUrlExternally(link)
            visible:            _thrustModelFactor
        }
        FactTextField {
            fact:               _thrustModelFactor
            visible:            _thrustModelFactor
        }
    }

    PIDTuning {
        id:                 pidTuning
        availableWidth:     _availableWidth
        availableHeight:    _availableHeight - pidTuning.y
        title:              qsTr("角速度")
        tuningMode:         Vehicle.ModeRateAndAttitude
        unit:               qsTr("deg/s")
        axis:               [ roll, pitch, yaw ]
        chartDisplaySec:    3
        showAutoModeChange: true
        showAutoTuning:     true

        property var roll: QtObject {
            property string name: qsTr("横滚")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.rollRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.rollRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("横滚比例增益 (MC_ROLLRATE_P)")
                    description:    qsTr("横滚比例增益: 增加以提高响应速度，减少如果速率超调 (增加 D 没有帮助)。")
                    param:          "MC_ROLLRATE_K"
                    min:            0.3
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("横滚微分增益 (MC_ROLLRATE_D)")
                    description:    qsTr("阻尼: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "MC_ROLLRATE_D"
                    min:            0.0004
                    max:            0.01
                    step:           0.0002
                }
                ListElement {
                    title:          qsTr("横滚积分增益 (MC_ROLLRATE_I)")
                    description:    qsTr("积分增益: 一般不需要调整，当看到缓慢振荡时减少。")
                    param:          "MC_ROLLRATE_I"
                    min:            0.1
                    max:            0.5
                    step:           0.025
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
                    title:          qsTr("俯仰比例增益 (MC_PITCHRATE_K)")
                    description:    qsTr("俯仰比例增益: 增加以提高响应速度，减少如果速率超调 (增加 D 没有帮助)。")
                    param:          "MC_PITCHRATE_K"
                    min:            0.3
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("俯仰微分增益 (MC_PITCHRATE_D)")
                    description:    qsTr("阻尼: 增加以减少超调和振荡，但不能高于真正需要的。")
                    param:          "MC_PITCHRATE_D"
                    min:            0.0004
                    max:            0.01
                    step:           0.0002
                }
                ListElement {
                    title:          qsTr("俯仰积分增益 (MC_PITCHRATE_I)")
                    description:    qsTr("积分增益: 一般不需要调整，当看到缓慢振荡时减少。")
                    param:          "MC_PITCHRATE_I"
                    min:            0.1
                    max:            0.5
                    step:           0.025
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
                    title:          qsTr("偏航比例增益 (MC_YAWRATE_K)")
                    description:    qsTr("偏航比例增益: 增加以提高响应速度，减少如果速率超调 (增加 D 没有帮助)。")
                    param:          "MC_YAWRATE_K"
                    min:            0.3
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("偏航积分增益 (MC_YAWRATE_I)")
                    description:    qsTr("积分增益: 一般不需要调整，当看到缓慢振荡时减少。")
                    param:          "MC_YAWRATE_I"
                    min:            0.04
                    max:            0.4
                    step:           0.02
                }
            }
        }
    }
}

