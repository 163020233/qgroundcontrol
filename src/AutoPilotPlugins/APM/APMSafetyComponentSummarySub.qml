import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    anchors.fill:   parent

    property bool   _firmware34: globals.activeVehicle.versionCompare(3, 5, 0) < 0

    FactPanelController { id: controller; }

    // Enable/Action parameters
    property Fact _failsafeBatteryEnable:     controller.getParameterFact(-1, "r.BATT_FS_LOW_ACT", false)
    property Fact _failsafeEKFEnable:         controller.getParameterFact(-1, "FS_EKF_ACTION")
    property Fact _failsafeGCSEnable:         controller.getParameterFact(-1, "FS_GCS_ENABLE")
    property Fact _failsafeLeakEnable:        controller.getParameterFact(-1, "FS_LEAK_ENABLE")
    property Fact _failsafePilotEnable:       _firmware34 ? null : controller.getParameterFact(-1, "FS_PILOT_INPUT")
    property Fact _failsafePressureEnable:    controller.getParameterFact(-1, "FS_PRESS_ENABLE")
    property Fact _failsafeTemperatureEnable: controller.getParameterFact(-1, "FS_TEMP_ENABLE")

    // Threshold parameters
    property Fact _failsafePressureThreshold:    controller.getParameterFact(-1, "FS_PRESS_MAX")
    property Fact _failsafeTemperatureThreshold: controller.getParameterFact(-1, "FS_TEMP_MAX")
    property Fact _failsafePilotTimeout:         _firmware34 ? null : controller.getParameterFact(-1, "FS_PILOT_TIMEOUT")
    property Fact _failsafeLeakPin:              controller.getParameterFact(-1, "LEAK1_PIN")
    property Fact _failsafeLeakLogic:            controller.getParameterFact(-1, "LEAK1_LOGIC")
    property Fact _failsafeEKFThreshold:         controller.getParameterFact(-1, "FS_EKF_THRESH")
    property Fact _failsafeBatteryVoltage:       controller.getParameterFact(-1, "r.BATT_LOW_VOLT", false)
    property Fact _failsafeBatteryCapacity:      controller.getParameterFact(-1, "r.BATT_LOW_MAH", false)

    property Fact _armingCheck: controller.getParameterFact(-1, "ARMING_CHECK")

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("设备检查")
            valueText:  _armingCheck.value & 1 ? qsTr("已启用") : qsTr("部分禁用")
        }
        VehicleSummaryRow {
            labelText: qsTr("GCS故障保护:")
            valueText: _failsafeGCSEnable.enumOrValueString
        }
        VehicleSummaryRow {
            labelText: qsTr("泄漏故障保护:")
            valueText:  _failsafeLeakEnable.enumOrValueString
        }
        VehicleSummaryRow {
            visible: !_firmware34
            labelText: qsTr("电池故障保护:")
            valueText: {
                if(_firmware34) {
                    return "固件不受支持"
                }

                if (!_failsafeBatteryEnable) {
                    return "已禁用"
                }

                return _failsafeBatteryEnable.enumOrValueString
            }
        }
        VehicleSummaryRow {
            visible: !_firmware34
            labelText: qsTr("EKF故障保护:")
            valueText: _firmware34 ? "" : _failsafeEKFEnable.enumOrValueString
        }
        VehicleSummaryRow {
            visible: !_firmware34
            labelText: qsTr("飞行输入故障保护:")
            valueText: _firmware34 ? "" : _failsafePilotEnable.enumOrValueString
        }
        VehicleSummaryRow {
            labelText: qsTr("内部温度故障保护:")
            valueText:  _failsafeTemperatureEnable.enumOrValueString
        }
        VehicleSummaryRow {
            labelText: qsTr("内部压力故障保护:")
            valueText:  _failsafePressureEnable.enumOrValueString
        }
    }
}
