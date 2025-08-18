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
            name: qsTr("固定翼初始检查")

            PreFlightCheckButton {
                name:           qsTr("硬件")
                manualText:     qsTr("螺旋桨是否安装？机翼是否安全？尾翼是否安全？")
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
                name:            qsTr("控制面")
                manualText:      qsTr("控制面是否正常？")
            }

            PreFlightCheckButton {
                name:            qsTr("电机")
                manualText:      qsTr("螺旋桨是否正常？电机是否正常？")
            }

            PreFlightCheckButton {
                name:           qsTr("任务")
                manualText:     qsTr("请确认任务有效（航点有效，无地形碰撞）")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("起飞前的最后准备")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:           qsTr("荷载")
                manualText:     qsTr("配置并启动? 有效载荷盖已关闭?")
            }

            PreFlightCheckButton {
                name:           qsTr("风速与天气")
                manualText:     qsTr("OK for your platform? Lauching into the wind?")
            }

            PreFlightCheckButton {
                name:           qsTr("起飞区域")
                manualText:     qsTr("起飞区域和路径是否清空？")
            }
        }
    }
}

