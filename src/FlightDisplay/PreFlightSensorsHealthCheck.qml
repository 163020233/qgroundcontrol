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
    name:               qsTr("传感器")
    telemetryFailure:   _unhealthySensors & _allCheckedSensors

    property int    _unhealthySensors:  globals.activeVehicle ? globals.activeVehicle.sensorsUnhealthyBits : 1
    property int    _allCheckedSensors: Vehicle.SysStatusSensor3dMag |
                                        Vehicle.SysStatusSensor3dAccel |
                                        Vehicle.SysStatusSensor3dGyro |
                                        Vehicle.SysStatusSensorAbsolutePressure |
                                        Vehicle.SysStatusSensorDifferentialPressure |
                                        Vehicle.SysStatusSensorGPS |
                                        Vehicle.SysStatusSensorAHRS

    on_UnhealthySensorsChanged: updateTelemetryTextFailure()

    Component.onCompleted: updateTelemetryTextFailure()

    function updateTelemetryTextFailure() {
        if(_unhealthySensors & _allCheckedSensors) {
            if (_unhealthySensors & Vehicle.SysStatusSensor3dMag)                       telemetryTextFailure = qsTr("失败，磁力计问题。请检查控制台。")
            else if(_unhealthySensors & Vehicle.SysStatusSensor3dAccel)                 telemetryTextFailure = qsTr("失败，加速度计问题。请检查控制台。")
            else if(_unhealthySensors & Vehicle.SysStatusSensor3dGyro)                  telemetryTextFailure = qsTr("失败，陀螺仪问题。请检查控制台。")
            else if(_unhealthySensors & Vehicle.SysStatusSensorAbsolutePressure)        telemetryTextFailure = qsTr("失败，气压计问题。请检查控制台。")
            else if(_unhealthySensors & Vehicle.SysStatusSensorDifferentialPressure)    telemetryTextFailure = qsTr("失败，空速传感器问题。请检查控制台。")
            else if(_unhealthySensors & Vehicle.SysStatusSensorAHRS)                    telemetryTextFailure = qsTr("失败，AHRS 问题。请检查控制台。")
            else if(_unhealthySensors & Vehicle.SysStatusSensorGPS)                     telemetryTextFailure = qsTr("失败，GPS 问题。请检查控制台。")
            else                                                                       telemetryTextFailure = qsTr("失败，未知传感器问题。请检查控制台。")
        } else {
            telemetryTextFailure = qsTr("传感器正常")
        }
    }
}
