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
    text:       _guidedController.armTitle            // 解锁/锁定 的动态标题
    iconSource: "/res/LockClosed.svg"                        // 你需要在 res 目录下放一个 arm.svg 图标
    visible:    _guidedController.showArm             // 是否显示
    enabled:    _guidedController.showArm             // 是否可用
    actionID:   _guidedController.actionArm           // 执行解锁/上锁动作
}