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

    property Fact _failsafeThrEnable:       controller.getParameterFact(-1, "FS_THR_ENABLE")

    property Fact _fenceAction:             controller.getParameterFact(-1, "FENCE_ACTION")
    property Fact _fenceEnable:             controller.getParameterFact(-1, "FENCE_ENABLE")
    property Fact _fenceType:               controller.getParameterFact(-1, "FENCE_TYPE")

    property Fact _rtlAltFact:              controller.getParameterFact(-1, "RTL_ALT")

    property Fact _armingCheck:             controller.getParameterFact(-1, "ARMING_CHECK")

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

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("设备检查")
            valueText: _armingCheck.value & 1 ? qsTr("已启用") : qsTr("某些已禁用")
        }

        VehicleSummaryRow {
            labelText: qsTr("油门故障保护")
            valueText: _failsafeThrEnable.enumStringValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池1低电压故障保护:")
            valueText:  _batt1MonitorEnabled ? _batt1FSLowAct.enumStringValue : ""
            visible:    _batt1MonitorEnabled
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池1关键故障保护:")
            valueText:  _batt1FSCritActAvailable ? _batt1FSCritAct.enumStringValue : ""
            visible:    _batt1FSCritActAvailable
        }

        VehicleSummaryRow {
            labelText:  qsTr("电池2低电压故障保护:")
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
            valueText: _fenceEnable.value == 0 || _fenceType == 0 ?
                           qsTr("已禁用") :
                           (_fenceType.value == 1 ?
                                qsTr("高度") :
                                (_fenceType.value == 2 ? qsTr("圆型") : qsTr("高度,圆型")))
        }

        VehicleSummaryRow {
            labelText: qsTr("地理围栏:")
            valueText: _fenceAction.value == 0 ?
                           qsTr("仅报告") :
                           (_fenceAction.value == 1 ? qsTr("RTL或降落") : qsTr("未知"))
            visible:    _fenceEnable.value != 0
        }

        VehicleSummaryRow {
            labelText: qsTr("RTL最小高度:")
            valueText: _rtlAltFact.value == 0 ? qsTr("当前高度") : _rtlAltFact.valueString + " " + _rtlAltFact.units
        }
    }
}
