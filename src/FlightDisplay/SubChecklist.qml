/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQml.Models

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.Vehicle

Item {
    property var model: listModel
    PreFlightCheckModel {
        id:     listModel
        PreFlightCheckGroup {
            name: qsTr("Sub 初始化检查")

            PreFlightCheckButton {
                name:           qsTr("硬件")
                manualText:     qsTr("所有密封是否就位？")
            }

            PreFlightBatteryCheck {
                failurePercent:                 40
                allowFailurePercentOverride:    false
            }

            PreFlightSensorsHealthCheck {
            }

            PreFlightGPSCheck {
                failureSatCount:        9
                allowOverrideSatCount:  true
            }

            PreFlightRCCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("请展开飞机旋翼")

            PreFlightCheckButton {
                name:            qsTr("电机")
                manualText:      qsTr("电机是否正常？")
            }

            PreFlightCheckButton {
                name:            qsTr("旋翼")
                manualText:      qsTr("旋翼是否正常？")
            }

            PreFlightCheckButton {
                name:           qsTr("任务")
                manualText:     qsTr("任务是否正常？")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("起飞前的最后准备")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:           qsTr("载荷")
                manualText:     qsTr("配置完毕并启动？有效载荷盖关好了吗？")
            }

        }
    }
}
