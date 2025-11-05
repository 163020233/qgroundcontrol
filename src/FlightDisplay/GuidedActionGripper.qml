/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QGroundControl.FlightDisplay
import QGroundControl

// GuidedToolStripAction {
//     property var   activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
//     property bool  _initialConnectComplete: activeVehicle ? activeVehicle.initialConnectComplete : false
//     property bool  _grip_enable:            _initialConnectComplete ? activeVehicle.hasGripper : false
//     property bool  _isVehicleArmed:         _initialConnectComplete ? activeVehicle.armed : false

//     text:       "夹爪"
//     iconSource: "/res/Gripper.svg"
//     // visible:    !_isVehicleArmed && _grip_enable   // in this way if the pilot it's on the ground can release the cargo without actions tool
//     visible: true
//     enabled:    true
//     actionID:   _guidedController.actionGripper
// }

GuidedToolStripAction {
    property var   activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property bool  _initialConnectComplete: activeVehicle ? activeVehicle.initialConnectComplete : true
    property bool  _grip_enable:            true   // ← 强制启用
    property bool  _isVehicleArmed:         false  // ← 模拟未上锁状态

    text:       "夹爪"
    iconSource: "/res/Gripper.svg"
    visible:    true    // ← 始终显示
    enabled:    true    // ← 始终可点
    actionID:   _guidedController.actionGripper
}
