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
import QGroundControl.FactSystem
import QGroundControl.FactControls
import MAVLink

BatteryIndicator {
    waitForParameters: true

    expandedPageComponent: Component {
        SettingsGroupLayout {
            Layout.fillWidth:   true
            heading:            qsTr("低电池保护")

            FactPanelController { id: controller }

            LabelledFactComboBox {
                label:              qsTr("设备操作")
                fact:               controller.getParameterFact(-1, "COM_LOW_BAT_ACT")
                indexModel:         false

                visible: fact && fact.name !== ""   // 如果没有对应参数就隐藏
                enabled: visible                    // 没有参数时不可用
            }

            FactSlider {
                Layout.fillWidth:       true
                label:                  qsTr("警告等级")
                fact:                   controller.getParameterFact(-1, "BAT_LOW_THR")
                majorTickStepSize:      5
            }   

            FactSlider {
                Layout.fillWidth:   true
                label:              qsTr("临界等级")
                fact:               controller.getParameterFact(-1, "BAT_CRIT_THR")
                majorTickStepSize:  5
            }

            FactSlider {
                Layout.fillWidth:   true
                label:              qsTr("紧急等级")
                fact:               controller.getParameterFact(-1, "BAT_EMERGEN_THR")
                majorTickStepSize:  5
            }
        }
    }
}
