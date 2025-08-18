/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Vehicle

PreFlightCheckButton {
    name:                   qsTr("无线电控制")
    manualText:             qsTr("接收信号，执行范围测试并确认。")
    telemetryTextFailure:   qsTr("无信号或自动驾驶仪RC 配置无效。请检查 RC 和控制台。")
    telemetryFailure:       false//_unhealthySensors & Vehicle.SysStatusSensorRCReceiver

    property int _unhealthySensors: globals.activeVehicle ? globals.activeVehicle.sensorsUnhealthyBits : 0
}
