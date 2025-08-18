import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.Palette

Item {
    anchors.fill:       parent

    AirframeComponentController { id: controller; }

    property Fact sysIdFact:        controller.getParameterFact(-1, "MAV_SYS_ID")
    property Fact sysAutoStartFact: controller.getParameterFact(-1, "SYS_AUTOSTART")

    property bool autoStartSet: sysAutoStartFact ? (sysAutoStartFact.value !== 0) : false

    Column {
        anchors.fill:       parent
        VehicleSummaryRow {
            labelText: qsTr("飞控ID")
            valueText: sysIdFact ? sysIdFact.valueString : ""
        }
        VehicleSummaryRow {
            labelText: qsTr("飞控类型")
            valueText: autoStartSet ? controller.currentAirframeType : qsTr("未设置")
        }
        VehicleSummaryRow {
            labelText: qsTr("飞控")
            valueText: autoStartSet ? controller.currentVehicleName : qsTr("未设置")
        }
        VehicleSummaryRow {
            labelText: qsTr("飞控版本")
            valueText: globals.activeVehicle.firmwareMajorVersion === -1 ? qsTr("未知") : globals.activeVehicle.firmwareMajorVersion + "." + globals.activeVehicle.firmwareMinorVersion + "." + globals.activeVehicle.firmwarePatchVersion + globals.activeVehicle.firmwareVersionTypeString
        }
        VehicleSummaryRow {
            visible: globals.activeVehicle.firmwareCustomMajorVersion !== -1
            labelText: qsTr("自定义飞控版本")
            valueText: globals.activeVehicle.firmwareCustomMajorVersion + "." + globals.activeVehicle.firmwareCustomMinorVersion + "." + globals.activeVehicle.firmwareCustomPatchVersion
        }
    }
}
