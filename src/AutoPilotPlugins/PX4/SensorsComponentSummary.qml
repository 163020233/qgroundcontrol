import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

/*
    IMPORTANT NOTE: Any changes made here must also be made to SensorsComponentSummary.qml
*/

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact mag0IdFact:   controller.getParameterFact(-1, "CAL_MAG0_ID")
    property Fact mag1IdFact:   controller.getParameterFact(-1, "CAL_MAG1_ID")
    property Fact mag2IdFact:   controller.getParameterFact(-1, "CAL_MAG2_ID")
    property Fact gyro0IdFact:  controller.getParameterFact(-1, "CAL_GYRO0_ID")
    property Fact accel0IdFact: controller.getParameterFact(-1, "CAL_ACC0_ID")

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("罗盘 0")
            valueText: mag0IdFact ? (mag0IdFact.value === 0 ? qsTr("需要设置") : qsTr("已准备")) : ""
        }

        VehicleSummaryRow {
            labelText:  qsTr("罗盘 1")
            visible:    mag1IdFact.value !== 0
            valueText:  qsTr("已准备")
        }

        VehicleSummaryRow {
            labelText:  qsTr("罗盘 2")
            visible:    mag2IdFact.value !== 0
            valueText:  qsTr("已准备")
        }

        VehicleSummaryRow {
            labelText: qsTr("陀螺仪")
            valueText: gyro0IdFact ? (gyro0IdFact.value === 0 ? qsTr("需要设置") : qsTr("已准备")) : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("加速度计")
            valueText: accel0IdFact ? (accel0IdFact.value === 0 ? qsTr("需要设置") : qsTr("已准备")) : ""
        }
    }
}
