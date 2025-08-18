import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact _mountRCInTilt:   controller.getParameterFact(-1, "MNT_RC_IN_TILT")
    property Fact _mountRCInRoll:   controller.getParameterFact(-1, "MNT_RC_IN_ROLL")
    property Fact _mountRCInPan:    controller.getParameterFact(-1, "MNT_RC_IN_PAN")

    // MNT_TYPE parameter is not in older firmware versions
    property bool   _mountTypeExists: controller.parameterExists(-1, "MNT_TYPE")
    property string _mountTypeValue: _mountTypeExists ? controller.getParameterFact(-1, "MNT_TYPE").enumStringValue : ""

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            visible:    _mountTypeExists
            labelText:  qsTr("万向架类型")
            valueText:  _mountTypeValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("倾斜输入通道")
            valueText:  _mountRCInTilt.enumStringValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("声像输入通道")
            valueText:  _mountRCInPan.enumStringValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("滚动输入通道")
            valueText:  _mountRCInRoll.enumStringValue
        }
    }
}
