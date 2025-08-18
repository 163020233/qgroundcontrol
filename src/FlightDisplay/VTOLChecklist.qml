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
            name: qsTr("VTOL起飞前检查")

            PreFlightCheckButton {
                name:           qsTr("硬件")
                manualText:     qsTr("电机、螺旋桨、机翼、尾翼是否安装好？")
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
            name: qsTr("请展开翼臂")

            PreFlightCheckButton {
                name:            qsTr("控制表面")
                manualText:      qsTr("请移动所有控制表面。它们是否正常工作？")
            }

            PreFlightCheckButton {
                name:            qsTr("电机")
                manualText:      qsTr("螺旋桨是否自由？然后缓慢增加油门。是否正常工作？")
            }

            PreFlightCheckButton {
                name:        qsTr("任务")
                manualText:  qsTr("请确认任务有效（航点有效，无地形碰撞）。")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("起飞前的最后准备")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:        qsTr("载荷")
                manualText:  qsTr("配置完毕并启动？有效载荷盖关好了吗？")
            }

            PreFlightCheckButton {
                name:        qsTr("环境")
                manualText:  qsTr("天气是否正常？是否有障碍物？")
            }

            PreFlightCheckButton {
                name:        qsTr("启动区域")
                manualText:  qsTr("启动区域和路径是否Clear？")
            }
        }
    }
}

