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

import QGroundControl
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

SetupPage {
    id:                 safetyPage
    pageComponent:      safetyPageComponent

    Component {
        id: safetyPageComponent

        Flow {
            id:         flowLayout
            width:      availableWidth
            spacing:    _margins

            FactPanelController { id: controller; }

            QGCPalette { id: ggcPal; colorGroupEnabled: true }

            property bool _firmware34:       globals.activeVehicle.versionCompare(3, 5, 0) < 0

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
            property bool _batteryDetected:              controller.parameterExists(-1, "r.BATT_LOW_MAH")

            property Fact _armingCheck: controller.getParameterFact(-1, "ARMING_CHECK")

            property real _margins:     ScreenTools.defaultFontPixelHeight
            property bool _showIcon:    !ScreenTools.isTinyScreen

            Column {
                spacing: _margins / 2

                QGCLabel {
                    id:         failsafeLabel
                    text:       qsTr("故障安全操作")
                    font.bold:   true
                }

                Rectangle {
                    id:     failsafeRectangle
                    width:  flowLayout.width
                    height: childrenRect.height + _margins
                    color:  ggcPal.windowShade

                    Column {
                        anchors.top: failsafeRectangle.top
                        anchors.left: failsafeRectangle.left
                        anchors.margins: _margins / 2
                        property var _labelWidth: ScreenTools.defaultFontPixelWidth * 15
                        property var _editWidth: ScreenTools.defaultFontPixelWidth * 20
                        id:     failsafeSettings
                        spacing: ScreenTools.defaultFontPixelHeight

                        Row {
                            spacing: _margins / 2

                            QGCLabel {
                                id:                     gcsEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: gcsEnableCombo.verticalCenter
                                text:                   qsTr("GCS 心跳:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                 gcsEnableCombo
                                width:              failsafeSettings._editWidth
                                fact:               _failsafeGCSEnable
                                indexModel:         false
                            }
                        }

                        Row {
                            spacing: _margins / 2

                            QGCLabel {
                                id:                     leakEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: leakEnableCombo.verticalCenter
                                text:                   qsTr("泄漏检测:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                     leakEnableCombo
                                width:                  failsafeSettings._editWidth
                                fact:                   _failsafeLeakEnable
                                indexModel:             false
                            }

                            QGCLabel {
                                text:                   qsTr("检测引脚:")
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: leakEnableCombo.verticalCenter
                                visible:                leakEnableCombo.currentIndex != 0
                            }

                            FactComboBox {
                                width:                  failsafeSettings._editWidth
                                visible:                leakEnableCombo.currentIndex != 0
                                anchors.verticalCenter: leakEnableCombo.verticalCenter
                                fact:                   _failsafeLeakPin
                                indexModel:             false
                            }

                            QGCLabel {
                                text:                   qsTr("Logic when Dry:")
                                width:                  failsafeSettings._labelWidth
                                visible:                leakEnableCombo.currentIndex != 0
                                anchors.verticalCenter: leakEnableCombo.verticalCenter
                            }

                            FactComboBox {
                                width:                  failsafeSettings._editWidth
                                visible:                leakEnableCombo.currentIndex != 0
                                anchors.verticalCenter: leakEnableCombo.verticalCenter
                                fact:                   _failsafeLeakLogic
                                indexModel:             false
                            }
                        }

                        Row {
                            spacing: _margins / 2
                            visible: !_firmware34

                            QGCLabel {
                                id:                     batteryEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: batteryEnableCombo.verticalCenter
                                text:                   qsTr("电池:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                 batteryEnableCombo
                                enabled:            _batteryDetected
                                width:              failsafeSettings._editWidth
                                fact:               _failsafeBatteryEnable
                                indexModel:         false
                            }

                            QGCLabel {
                                text:                   qsTr("电池未设置")
                                width:                  failsafeSettings._labelWidth
                                color:                  ggcPal.warningText
                                anchors.verticalCenter: batteryEnableCombo.verticalCenter
                                visible:                !_batteryDetected
                            }

                            QGCLabel {
                                text:                   qsTr("电压:")
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: batteryEnableCombo.verticalCenter
                                visible:                batteryEnableCombo.currentIndex != 0
                            }

                            FactTextField {
                                width:                  failsafeSettings._editWidth
                                anchors.verticalCenter: batteryEnableCombo.verticalCenter
                                visible:                batteryEnableCombo.currentIndex != 0
                                fact:                   _failsafeBatteryVoltage
                            }

                            QGCLabel {
                                text:                   qsTr("剩余容量:")
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: batteryEnableCombo.verticalCenter
                                visible:                batteryEnableCombo.currentIndex != 0
                            }

                            FactTextField {
                                width:                  failsafeSettings._editWidth
                                anchors.verticalCenter: batteryEnableCombo.verticalCenter
                                visible:                batteryEnableCombo.currentIndex != 0
                                fact:                   _failsafeBatteryCapacity
                            }
                        }

                        Row {
                            spacing: _margins / 2
                            visible: !_firmware34

                            QGCLabel {
                                id:                     ekfEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: ekfEnableCombo.verticalCenter
                                text:                   qsTr("EKF:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                 ekfEnableCombo
                                width:              failsafeSettings._editWidth
                                fact:               _failsafeEKFEnable
                                indexModel:         false
                            }

                            QGCLabel {
                                text: "Threshold:"
                                width:              failsafeSettings._labelWidth
                                visible:            ekfEnableCombo.currentIndex != 0
                                anchors.baseline:   ekfEnableCombo.baseline
                            }

                            FactTextField {
                                width:              failsafeSettings._editWidth
                                visible:            ekfEnableCombo.currentIndex != 0
                                anchors.baseline:   ekfEnableCombo.baseline
                                fact:               _failsafeEKFThreshold
                            }
                        }

                        Row {
                            spacing: _margins / 2
                            visible: !_firmware34

                            QGCLabel {
                                id:                     pilotEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: pilotEnableCombo.verticalCenter
                                text:                   qsTr("飞行输入:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                 pilotEnableCombo
                                width:              failsafeSettings._editWidth
                                fact:               _failsafePilotEnable
                                indexModel:         false
                            }

                            QGCLabel {
                                text:                   qsTr("超时:")
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: pilotEnableCombo.verticalCenter
                                visible:                pilotEnableCombo.currentIndex != 0

                            }

                            FactTextField {
                                width:                  failsafeSettings._editWidth
                                anchors.verticalCenter: pilotEnableCombo.verticalCenter
                                visible:                pilotEnableCombo.currentIndex != 0
                                anchors.baseline:       pilotEnableCombo.baseline
                                fact:                   _failsafePilotTimeout
                            }
                        }

                        Row {
                            spacing: _margins / 2

                            QGCLabel {
                                id:                     temperatureEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: temperatureEnableCombo.verticalCenter
                                text:                   qsTr("内部温度:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                 temperatureEnableCombo
                                width:              failsafeSettings._editWidth
                                fact:               _failsafeTemperatureEnable
                                indexModel:         false
                            }

                            QGCLabel {
                                text:               qsTr("温度阈值:")
                                width:              failsafeSettings._labelWidth
                                visible:            temperatureEnableCombo.currentIndex != 0
                                anchors.baseline:   temperatureEnableCombo.baseline
                            }

                            FactTextField {
                                width:              failsafeSettings._editWidth
                                visible:            temperatureEnableCombo.currentIndex != 0
                                anchors.baseline:   temperatureEnableCombo.baseline
                                fact:               _failsafeTemperatureThreshold
                            }
                        }

                        Row {
                            spacing: _margins / 2

                            QGCLabel {
                                id:                     pressureEnableLabel
                                width:                  failsafeSettings._labelWidth
                                anchors.verticalCenter: pressureEnableCombo.verticalCenter
                                text:                   qsTr("内部压力:")
                                wrapMode:               Text.Wrap
                            }

                            FactComboBox {
                                id:                 pressureEnableCombo
                                width:              failsafeSettings._editWidth
                                fact:               _failsafePressureEnable
                                indexModel:         false
                            }

                            QGCLabel {
                                text:               qsTr("压力阈值:")
                                width:              failsafeSettings._labelWidth
                                visible:            pressureEnableCombo.currentIndex != 0
                                anchors.baseline:   pressureEnableCombo.baseline
                            }

                            FactTextField {
                                width:              failsafeSettings._editWidth
                                visible:            pressureEnableCombo.currentIndex != 0
                                anchors.baseline:   pressureEnableCombo.baseline
                                fact:               _failsafePressureThreshold
                            }
                        }
                    } // Column - Failsafe Settings
                }// Rectangle - Failsafe Settings
            } // Column - Failsafe Settings

            Column {
                spacing: _margins / 2

                QGCLabel {
                    text:           qsTr("设备检查")
                    font.bold:      true
                }

                Rectangle {
                    width:  flowLayout.width
                    height: armingCheckInnerColumn.height + (_margins * 2)
                    color:  ggcPal.windowShade

                    Column {
                        id:                 armingCheckInnerColumn
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        spacing: _margins

                        FactBitmask {
                            id:                 armingCheckBitmask
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            firstEntryIsAll:    true
                            fact:               _armingCheck
                        }

                        QGCLabel {
                            id:             armingCheckWarning
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            color:          qgcPal.warningText
                            text:            qsTr("警告: 关闭设备检查可能会导致设备控制丢失。")
                            visible:        _armingCheck.value != 1
                        }
                    }
                } // Rectangle - Arming checks
            } // Column - Arming Checks
        } // Flow
    } // Component - safetyPageComponent
} // SetupView
