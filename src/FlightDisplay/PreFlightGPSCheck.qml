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
    name:                           qsTr("GPS")
    telemetryFailure:               _3dLockFailure || _satCountFailure
    telemetryTextFailure:           _3dLockFailure ?
                                        qsTr("等待3D锁定") :
                                        (_satCountFailure ? _satCountFailureText : "")
    allowTelemetryFailureOverride:  !_3dLockFailure && _satCountFailure && allowOverrideSatCount

    property bool   allowOverrideSatCount:  false   ///< true: sat count above failureSatCount reguired to pass, false: user can click past satCount <= failureSetCount
    property int    failureSatCount:        -1      ///< -1 indicates no sat count check

    property bool   _3dLock:                globals.activeVehicle ? globals.activeVehicle.gps.lock.rawValue >= 3 : false
    property int    _satCount:              globals.activeVehicle ? globals.activeVehicle.gps.count.rawValue : 0
    property bool   _3dLockFailure:         !_3dLock
    property bool   _satCountFailure:       failureSatCount !== -1 && _satCount <= failureSatCount
    property string _satCountFailureText:   allowOverrideSatCount ? qsTr("警告 - 卫星数量低于%1.").arg(failureSatCount + 1) : qsTr("等待卫星数量高于%1.").arg(failureSatCount)
}
