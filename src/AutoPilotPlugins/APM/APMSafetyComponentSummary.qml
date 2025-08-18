import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact _copterFenceAction:       controller.getParameterFact(-1, "FENCE_ACTION", false /* reportMissing */)
    property Fact _copterFenceEnable:       controller.getParameterFact(-1, "FENCE_ENABLE", false /* reportMissing */)
    property Fact _copterFenceType:         controller.getParameterFact(-1, "FENCE_TYPE", false /* reportMissing */)

    property Fact _batt1Monitor:            controller.getParameterFact(-1, "BATT_MONITOR")
    property Fact _batt2Monitor:            controller.getParameterFact(-1, "BATT2_MONITOR", false /* reportMissing */)
    property bool _batt2MonitorAvailable:   controller.parameterExists(-1, "BATT2_MONITOR")
    property bool _batt1MonitorEnabled:     _batt1Monitor.rawValue !== 0
    property bool _batt2MonitorEnabled:     _batt2MonitorAvailable && _batt2Monitor.rawValue !== 0

    property Fact _batt1FSLowAct:           controller.getParameterFact(-1, "r.BATT_FS_LOW_ACT", false /* reportMissing */)
    property Fact _batt1FSCritAct:          controller.getParameterFact(-1, "BATT_FS_CRT_ACT", false /* reportMissing */)
    property Fact _batt2FSLowAct:           controller.getParameterFact(-1, "BATT2_FS_LOW_ACT", false /* reportMissing */)
    property Fact _batt2FSCritAct:          controller.getParameterFact(-1, "BATT2_FS_CRT_ACT", false /* reportMissing */)
    property bool _batt1FSCritActAvailable: controller.parameterExists(-1, "BATT_FS_CRT_ACT")

    property bool _roverFirmware:           controller.parameterExists(-1, "MODE1") // This catches all usage of ArduRover firmware vehicle types: Rover, Boat...


    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("设备检查")
            valueText: fact ? (fact.value & 1 ? qsTr("已启用") : qsTr("部分禁用")) : ""

            property Fact fact: controller.getParameterFact(-1, "ARMING_CHECK")
        }

        VehicleSummaryRow {
            labelText:  qsTr("油门故障保护")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    controller.vehicle.multiRotor

            property Fact fact: controller.getParameterFact(-1, "FS_THR_ENABLE", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("油门故障保护")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    controller.vehicle.fixedWing

            property Fact fact: controller.getParameterFact(-1, "THR_FAILSAFE", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("油门故障保护")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    _roverFirmware

            property Fact fact: controller.getParameterFact(-1, "FS_THR_ENABLE", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("故障安全措施:")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    _roverFirmware

            property Fact fact: controller.getParameterFact(-1, "FS_ACTION", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("故障安全碰撞检查：")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    _roverFirmware

            property Fact fact: controller.getParameterFact(-1, "FS_CRASH_CHECK", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池1低故障保护:")
            valueText:  _batt1MonitorEnabled ? _batt1FSLowAct.enumStringValue : ""
            visible:    _batt1MonitorEnabled
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池1关键故障保护:")
            valueText:  _batt1FSCritActAvailable ? _batt1FSCritAct.enumStringValue : ""
            visible:    _batt1FSCritActAvailable
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池2低故障保护:")
            valueText:  _batt2MonitorEnabled ? _batt2FSLowAct.enumStringValue : ""
            visible:    _batt2MonitorEnabled
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池2关键故障保护:")
            valueText:  _batt2MonitorEnabled ? _batt2FSCritAct.enumStringValue : ""
            visible:    _batt2MonitorEnabled
        }

        VehicleSummaryRow {
            labelText: qsTr("地理围栏:")
            valueText: {
                if(_copterFenceEnable && _copterFenceType) {
                    if(_copterFenceEnable.value == 0 || _copterFenceType == 0) {
                        return qsTr("已禁用")
                    } else {
                        if(_copterFenceType.value == 1) {
                            return qsTr("高度")
                        }
                        if(_copterFenceType.value == 2) {
                            return qsTr("圆型")
                        }
                        return qsTr("高度,圆型")
                    }
                }
                return ""
            }
            visible: controller.vehicle.multiRotor
        }

        VehicleSummaryRow {
            labelText: qsTr("地理围栏:")
            valueText: _copterFenceAction.value == 0 ?
                           qsTr("仅报告") :
                           (_copterFenceAction.value == 1 ? qsTr("RTL或降落") : qsTr("未知"))
            visible: controller.vehicle.multiRotor && _copterFenceEnable.value !== 0
        }

        VehicleSummaryRow {
            labelText:  qsTr("RTL最小高度:")
            valueText:  fact ? (fact.value == 0 ? qsTr("当前高度") : fact.valueString + " " + fact.units) : ""
            visible:    controller.vehicle.multiRotor

            property Fact fact: controller.getParameterFact(-1, "RTL_ALT", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("RTL最小高度:")
            valueText:  fact ? (fact.value < 0 ? qsTr("当前高度") : fact.valueString + " " + fact.units) : ""
            visible:    controller.vehicle.fixedWing

            property Fact fact: controller.getParameterFact(-1, "ALT_HOLD_RTL", false /* reportMissing */)
        }
    }
}
