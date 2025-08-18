import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact mapRollFact:      controller.getParameterFact(-1, "RCMAP_ROLL")
    property Fact mapPitchFact:     controller.getParameterFact(-1, "RCMAP_PITCH")
    property Fact mapYawFact:       controller.getParameterFact(-1, "RCMAP_YAW")
    property Fact mapThrottleFact:  controller.getParameterFact(-1, "RCMAP_THROTTLE")

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("滚转")
            valueText: mapRollFact.value == 0 ? qsTr("未设置") : qsTr("通道 %1").arg(mapRollFact.valueString)
        }

        VehicleSummaryRow {
            labelText: qsTr("俯仰")
            valueText: mapPitchFact.value == 0 ? qsTr("未设置") : qsTr("通道 %1").arg(mapPitchFact.valueString)
        }

        VehicleSummaryRow {
            labelText: qsTr("偏航")
            valueText: mapYawFact.value == 0 ? qsTr("未设置") : qsTr("通道 %1").arg(mapYawFact.valueString)
        }

        VehicleSummaryRow {
            labelText: qsTr("油门")
            valueText: mapThrottleFact.value == 0 ? qsTr("未设置") : qsTr("通道 %1").arg(mapThrottleFact.valueString)
        }
    }
}
