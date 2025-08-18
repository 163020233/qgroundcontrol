/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    anchors.fill: parent

    FactPanelController { id: controller }

    function getFact(name) {
        return controller.getParameterFact(-1, name, false)
    }

    property bool followParamsAvailable: controller.parameterExists(-1, "FOLL_SYSID")

    property var followItems: [
        { label: qsTr("跟随已启用"),    fact: getFact("FOLL_ENABLE"),       visible: true},
        { label: qsTr("跟随系统ID"),  fact: getFact("FOLL_SYSID"),        visible: followParamsAvailable },
        { label: qsTr("最大距离"),      fact: getFact("FOLL_DIST_MAX"),     visible: followParamsAvailable },
        { label: qsTr("X偏移"),          fact: getFact("FOLL_OFS_X"),        visible: followParamsAvailable },
        { label: qsTr("Y偏移"),          fact: getFact("FOLL_OFS_Y"),        visible: followParamsAvailable },
        { label: qsTr("Z偏移"),          fact: getFact("FOLL_OFS_Z"),        visible: followParamsAvailable },
        { label: qsTr("偏移类型"),       fact: getFact("FOLL_OFS_TYPE"),     visible: followParamsAvailable },
        { label: qsTr("高度类型"),     fact: getFact("FOLL_ALT_TYPE"),     visible: followParamsAvailable },
        { label: qsTr("Yaw 行为"),      fact: getFact("FOLL_YAW_BEHAVE"),   visible: followParamsAvailable }
    ]

    Column {
        anchors.fill: parent

        Repeater {
            model: followItems
            delegate: VehicleSummaryRow {
                labelText: modelData.label
                valueText: formatFact(modelData.fact)
                visible: modelData.visible

                function formatFact(fact) {
                    return (fact && (fact.enumStringValue || (fact.valueString + " " + fact.units)))
                }
            }
        }
    }
}
