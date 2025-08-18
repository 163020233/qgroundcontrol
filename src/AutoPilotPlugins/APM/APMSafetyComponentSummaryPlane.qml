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

    property Fact _failsafeBattMah:     controller.getParameterFact(-1, "FS_BATT_MAH")
    property Fact _failsafeBattVoltage: controller.getParameterFact(-1, "FS_BATT_VOLTAGE")
    property Fact _failsafeThrEnable:   controller.getParameterFact(-1, "THR_FAILSAFE")
    property Fact _failsafeThrValue:    controller.getParameterFact(-1, "THR_FS_VALUE")
    property Fact _failsafeGCSEnable:   controller.getParameterFact(-1, "FS_GCS_ENABL")

    property Fact _rtlAltFact: {
        if (controller.firmwareMajorVersion < 4 || (controller.firmwareMajorVersion === 4 && controller.firmwareMinorVersion < 5)) {
            return controller.getParameterFact(-1, "ALT_HOLD_RTL")
        } else {
            return controller.getParameterFact(-1, "RTL_ALTITUDE")
        }
    }

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("油门故障保护")
            valueText:  _failsafeThrEnable.value != 0 ? _failsafeThrValue.valueString : qsTr("已禁用")
        }

        VehicleSummaryRow {
            labelText: qsTr("电池电压故障保护:")
            valueText:  _failsafeBattVoltage.value == 0 ? qsTr("已禁用") : _failsafeBattVoltage.valueString + " " + _failsafeBattVoltage.units
        }

        VehicleSummaryRow {
            labelText: qsTr("电池容量故障保护:")
            valueText:  _failsafeBattMah.value == 0 ? qsTr("已禁用") : _failsafeBattMah.valueString + " " + _failsafeBattMah.units
        }

        VehicleSummaryRow {
            labelText: qsTr("RTL最小高度:")
            valueText: _rtlAltFact.value < 0 ? qsTr("当前高度") : _rtlAltFact.valueString + " " + _rtlAltFact.units
        }
    }
}
