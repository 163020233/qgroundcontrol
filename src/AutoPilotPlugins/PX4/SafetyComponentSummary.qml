import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact   returnAltFact:      controller.getParameterFact(-1, "RTL_RETURN_ALT")
    property Fact   _descendAltFact:    controller.getParameterFact(-1, "RTL_DESCEND_ALT")
    property Fact   landDelayFact:      controller.getParameterFact(-1, "RTL_LAND_DELAY")
    property Fact   commRCLossFact:     controller.getParameterFact(-1, "COM_RC_LOSS_T")
    property Fact   lowBattAction:      controller.getParameterFact(-1, "COM_LOW_BAT_ACT")
    property Fact   rcLossAction:       controller.getParameterFact(-1, "NAV_RCL_ACT")
    property Fact   dataLossAction:     controller.getParameterFact(-1, "NAV_DLL_ACT")
    property Fact   _rtlLandDelayFact:  controller.getParameterFact(-1, "RTL_LAND_DELAY")
    property int    _rtlLandDelayValue: _rtlLandDelayFact.value

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("低电池保护")
            valueText: lowBattAction ? lowBattAction.enumStringValue : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RC 丢失保护")
            valueText: rcLossAction ? rcLossAction.enumStringValue : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RC 丢失超时")
            valueText: commRCLossFact ? commRCLossFact.valueString + " " + commRCLossFact.units : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("数据链路丢失保护")
            valueText: dataLossAction ? dataLossAction.enumStringValue : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RTL 爬升高度")
            valueText: returnAltFact ? returnAltFact.valueString + " " + returnAltFact.units : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RTL, 然后")
            valueText: _rtlLandDelayValue === 0 ?
                           qsTr("立即降落") :
                           (_rtlLandDelayValue < 0 ?
                                qsTr("盘旋并不降落") :
                                qsTr("盘旋并在指定时间后降落"))

        }

        VehicleSummaryRow {
            labelText: qsTr("盘旋高度")
            valueText: _descendAltFact.valueString + " " + _descendAltFact.units
            visible:    _rtlLandDelayValue !== 0
        }

        VehicleSummaryRow {
            labelText: qsTr("延迟降落")
            valueText: _rtlLandDelayValue + " " + _rtlLandDelayFact.units
            visible:    _rtlLandDelayValue > 0
        }
    }
}
