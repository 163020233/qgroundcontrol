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
            name: qsTr("Rover 初始化检查")

            PreFlightCheckButton {
                name:           qsTr("硬件检查")
                manualText:     qsTr("电池已安装并安全？")
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
            name: qsTr("请先启动设备")

            PreFlightCheckButton {
                name:           qsTr("任务")
                manualText:     qsTr("请确认任务有效（航点有效，无地形碰撞）。")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("起飞前准备")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:           qsTr("载荷")
                manualText:     qsTr("配置完毕并启动？有效载荷盖关好了吗？")
            }

            PreFlightCheckButton {
                name:           qsTr("风、天气")
                manualText:     qsTr("平台是否适合飞行？")
            }

            PreFlightCheckButton {
                name:           qsTr("任务区域")
                manualText:     qsTr("任务区域和路径是否无障碍物/人？")
            }
        }
    }
}
