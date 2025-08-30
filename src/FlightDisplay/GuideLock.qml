/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
//
import QGroundControl.FlightDisplay

GuidedToolStripAction {
    text:       _guidedController.disarmTitle         // 上锁
    iconSource: "/res/LockOpen.svg"
    visible:    _guidedController.showDisarm          // 显示条件：可以上锁时显示
    enabled:    _guidedController.showDisarm
    actionID:   _guidedController.actionDisarm
}