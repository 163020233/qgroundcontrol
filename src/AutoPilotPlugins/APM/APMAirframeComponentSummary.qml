import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.Palette

Item {
    anchors.fill:       parent

    APMAirframeComponentController {id: controller; }

    property Fact _frameClass:          controller.getParameterFact(-1, "FRAME_CLASS")
    property Fact _frameType:           controller.getParameterFact(-1, "FRAME_TYPE", false)
    property bool _frameTypeAvailable:  controller.parameterExists(-1, "FRAME_TYPE")

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText:  qsTr("框架类型:")
            valueText:  _frameClass.enumStringValue

        }

        VehicleSummaryRow {
            labelText:  qsTr("框架类型")
            valueText:  visible ? _frameType.enumStringValue : ""
            visible:    _frameTypeAvailable
        }

        VehicleSummaryRow {
            labelText: qsTr("固件版本")
            valueText: globals.activeVehicle.firmwareMajorVersion == -1 ? qsTr("未知") : globals.activeVehicle.firmwareMajorVersion + "." + globals.activeVehicle.firmwareMinorVersion + "." + globals.activeVehicle.firmwarePatchVersion + globals.activeVehicle.firmwareVersionTypeString
        }
    }
}
