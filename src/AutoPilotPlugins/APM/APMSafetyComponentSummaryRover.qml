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

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    anchors.fill:   parent
    color:          qgcPal.windowShadeDark

    FactPanelController { id: controller; }

    property Fact _failsafeThrEnable:   controller.getParameterFact(-1, "FS_THR_ENABLE")
    property Fact _failsafeThrValue:    controller.getParameterFact(-1, "FS_THR_VALUE")
    property Fact _failsafeAction:      controller.getParameterFact(-1, "FS_ACTION")
    property Fact _failsafeCrashCheck:  controller.getParameterFact(-1, "FS_CRASH_CHECK")

    property Fact _armingCheck:         controller.getParameterFact(-1, "ARMING_CHECK")

    property string _failsafeActionText
    property string _failsafeCrashCheckText

    Component.onCompleted: {
        setFailsafeActionText()
        setFailsafeCrashCheckText()
    }

    Connections {
        target: _failsafeAction

        onValueChanged: setFailsafeActionText()
    }

    Connections {
        target: _failsafeCrashCheck

        onValueChanged: setFailsafeCrashCheckText()
    }

    function setFailsafeActionText() {
        switch (_failsafeAction.value) {
        case 0:
            _failsafeActionText = qsTr("已禁用")
            break
        case 1:
            _failsafeActionText = qsTr("总是返回")
            break
        case 2:
            _failsafeActionText = qsTr("永远保持位置")

            break
        default:
            _failsafeActionText = qsTr("未知")
        }
    }

    function setFailsafeCrashCheckText() {
        switch (_failsafeCrashCheck.value) {
        case 0:
            _failsafeCrashCheckText = qsTr("已禁用")
            break
        case 1:
            _failsafeCrashCheckText = qsTr("保持位置")
            break
        case 2:
            _failsafeCrashCheckText = qsTr("保持位置并断开")
            break
        default:
            _failsafeCrashCheckText = qsTr("未知")
        }
    }

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("设备检查")
            valueText:  _armingCheck.value & 1 ? qsTr("已启用") : qsTr("部分已禁用")
        }

        VehicleSummaryRow {
            labelText: qsTr("油门故障保护")
            valueText:  _failsafeThrEnable.value != 0 ? _failsafeThrValue.valueString : qsTr("已禁用")
        }

        VehicleSummaryRow {
            labelText: qsTr("故障安全措施:")
            valueText: _failsafeActionText
        }

        VehicleSummaryRow {
            labelText: qsTr("故障安全碰撞检查：")
            valueText: _failsafeCrashCheckText
        }

    }
}
