import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.Controllers
/*
    IMPORTANT NOTE: Any changes made here must also be made to SensorsComponentSummary.qml
*/

Item {
    anchors.fill:   parent

    APMSensorsComponentController { id: controller; }

    APMSensorParams {
        id:                     sensorParams
        factPanelController:    controller
    }

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
        labelText:  qsTr("指南针:")
        valueText: ""
        }

        Repeater {
            model: sensorParams.rgCompassAvailable.length
            RowLayout {
                Layout.fillWidth: true
                width: parent.width

                QGCLabel {

                    text:  sensorParams.rgCompassAvailable[index] ?
                                (sensorParams.rgCompassCalibrated[index] ?
                                     getPriority(index) +
                                     (sensorParams.rgCompassExternalParamAvailable[index] ?
                                          (sensorParams.rgCompassExternal[index] ? ", External" : ", Internal" ) :
                                          "") :
                                     qsTr("校准需要")) :
                                qsTr("未安装")

                    function getPriority (index) {
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[0].value) {
                            return "Primary"
                        }
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[1].value) {
                            return "Secondary"
                        }
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[2].value) {
                            return "Tertiary"
                        }
                        return "Unused"
                    }
                }

                APMSensorIdDecoder {
                    horizontalAlignment:    Text.AlignRight
                    Layout.alignment:       Qt.AlignRight

                    fact: sensorParams.rgCompassPrio[index]
                }
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("加速度计:")
            valueText: controller.accelSetupNeeded ? qsTr("校准需要") : qsTr("已准备就绪")
        }

        Repeater {
            model: sensorParams.rgInsId.length
            APMSensorIdDecoder {
                fact:          sensorParams.rgInsId[index]
                anchors.right: parent.right
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("气压计:")
            valueText: sensorParams.baroIdAvailable ? "" : qsTr("不支持(APM 4.1及以上)")
        }

        Repeater {
            model: sensorParams.rgBaroId.length
            APMSensorIdDecoder {
                fact:          sensorParams.rgBaroId[index]
                anchors.right: parent.right
            }
        }
    }
}
