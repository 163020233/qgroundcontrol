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
            name: qsTr("多旋翼飞行器初始检查")

            PreFlightCheckButton {
                name:           qsTr("硬件")
                manualText:     qsTr("电机、螺旋桨、电池和传感器是否安装正确？")
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
            name: qsTr("请先启动飞行器")

            PreFlightCheckButton {
                name:            qsTr("电机")
                manualText:      qsTr("螺旋桨是否自由？然后缓慢增加油门。是否正常工作？")
            }

            PreFlightCheckButton {
                name:           qsTr("任务")
                manualText:     qsTr("请确认任务是否有效（航点有效，无地形碰撞）。")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("最后准备起飞")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:           qsTr("负载")
                manualText:     qsTr("已配置并启动？负载盖已关闭？")
            }

            PreFlightCheckButton {
                name:           qsTr("风速和天气")
                manualText:     qsTr("您的平台是否正常？")
            }

            PreFlightCheckButton {
                name:           qsTr("起飞区域")
                manualText:     qsTr("起飞区域和路径是否无障碍物/人？")
            }
        }
    }
}

