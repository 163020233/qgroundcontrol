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
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

SetupPage {
    id:             powerPage
    pageComponent:  powerPageComponent

    FactPanelController {
        id:         controller
    }

    Component {
        id: powerPageComponent

        Flow {
            id:         flowLayout
            width:      availableWidth
            spacing:    _margins

            property Fact _batt1Monitor:            controller.getParameterFact(-1, "BATT_MONITOR")
            property Fact _batt2Monitor:            controller.getParameterFact(-1, "BATT2_MONITOR", false /* reportMissing */)
            property bool _batt2MonitorAvailable:   controller.parameterExists(-1, "BATT2_MONITOR")
            property bool _batt1MonitorEnabled:     _batt1Monitor.rawValue !== 0
            property bool _batt2MonitorEnabled:     _batt2MonitorAvailable && _batt2Monitor.rawValue !== 0
            property bool _batt1ParamsAvailable:    controller.parameterExists(-1, "BATT_CAPACITY")
            property bool _batt2ParamsAvailable:    controller.parameterExists(-1, "BATT2_CAPACITY")
            property bool _showBatt1Reboot:         _batt1MonitorEnabled && !_batt1ParamsAvailable
            property bool _showBatt2Reboot:         _batt2MonitorEnabled && !_batt2ParamsAvailable
            property bool _escCalibrationAvailable: controller.parameterExists(-1, "ESC_CALIBRATION")
            property Fact _escCalibration:          controller.getParameterFact(-1, "ESC_CALIBRATION", false /* reportMissing */)

            property string _restartRequired: qsTr("需要重新启动")

            QGCPalette { id: ggcPal; colorGroupEnabled: true }

            // Battery1 Monitor settings only - used when only monitor param is available
            Column {
                spacing: _margins / 2
                visible: !_batt1MonitorEnabled || !_batt1ParamsAvailable

                QGCLabel {
                    text:       qsTr("电池 1")
                    font.bold:   true
                }

                Rectangle {
                    width:  batt1Column.x + batt1Column.width + _margins
                    height: batt1Column.y + batt1Column.height + _margins
                    color:  ggcPal.windowShade

                    ColumnLayout {
                        id:                 batt1Column
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        spacing:            ScreenTools.defaultFontPixelWidth

                        RowLayout {
                            id:                 batt1MonitorRow
                            spacing:            ScreenTools.defaultFontPixelWidth

                            QGCLabel { text: qsTr("电池 1 监控:") }
                            FactComboBox {
                                id:         monitor1Combo
                                fact:       _batt1Monitor
                                indexModel: false
                                sizeToContents: true
                            }
                        }

                        QGCLabel {
                            text:       _restartRequired
                            visible:    _showBatt1Reboot
                        }

                        QGCButton {
                            text:       qsTr("重新启动")
                            visible:    _showBatt1Reboot
                            onClicked:  controller.vehicle.rebootVehicle()
                        }
                    }
                }
            }

            // Battery 1 settings
            Column {
                id:         _batt1FullSettings
                spacing:    _margins / 2
                visible:    _batt1MonitorEnabled && _batt1ParamsAvailable

                QGCLabel {
                    text:       qsTr("电池 1")
                    font.bold:   true
                }

                Rectangle {
                    width:  battery1Loader.x + battery1Loader.width + _margins
                    height: battery1Loader.y + battery1Loader.height + _margins
                    color:  ggcPal.windowShade

                    Loader {
                        id:                 battery1Loader
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        sourceComponent:    _batt1FullSettings.visible ? powerSetupComponent : undefined

                        property Fact armVoltMin:       controller.getParameterFact(-1, "r.BATT_ARM_VOLT", false /* reportMissing */)
                        property Fact battAmpPerVolt:   controller.getParameterFact(-1, "r.BATT_AMP_PERVLT", false /* reportMissing */)
                        property Fact battAmpOffset:    controller.getParameterFact(-1, "BATT_AMP_OFFSET", false /* reportMissing */)
                        property Fact battCapacity:     controller.getParameterFact(-1, "BATT_CAPACITY", false /* reportMissing */)
                        property Fact battCurrPin:      controller.getParameterFact(-1, "BATT_CURR_PIN", false /* reportMissing */)
                        property Fact battMonitor:      controller.getParameterFact(-1, "BATT_MONITOR", false /* reportMissing */)
                        property Fact battVoltMult:     controller.getParameterFact(-1, "BATT_VOLT_MULT", false /* reportMissing */)
                        property Fact battVoltPin:      controller.getParameterFact(-1, "BATT_VOLT_PIN", false /* reportMissing */)
                        property FactGroup  _batteryFactGroup:  _batt1FullSettings.visible ? controller.vehicle.getFactGroup("battery0") : null
                        property Fact vehicleVoltage:   _batteryFactGroup ? _batteryFactGroup.voltage : null
                        property Fact vehicleCurrent:   _batteryFactGroup ? _batteryFactGroup.current : null
                    }
                }
            }

            // Battery2 Monitor settings only - used when only monitor param is available
            Column {
                spacing: _margins / 2
                visible: !_batt2MonitorEnabled || !_batt2ParamsAvailable

                QGCLabel {
                    text:       qsTr("电池 2")
                    font.bold:   true
                }

                Rectangle {
                    width:  batt2Column.x + batt2Column.width + _margins
                    height: batt2Column.y + batt2Column.height + _margins
                    color:  ggcPal.windowShade

                    ColumnLayout {
                        id:                 batt2Column
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        spacing:            ScreenTools.defaultFontPixelWidth

                        RowLayout {
                            id:                 batt2MonitorRow
                            spacing:            ScreenTools.defaultFontPixelWidth

                            QGCLabel { text: qsTr("电池 2 监控:") }
                            FactComboBox {
                                id:         monitor2Combo
                                fact:       _batt2Monitor
                                indexModel: false
                                sizeToContents: true
                            }
                        }

                        QGCLabel {
                            text:       _restartRequired
                            visible:    _showBatt2Reboot
                        }

                        QGCButton {
                            text:       qsTr("重新启动")
                            visible:    _showBatt2Reboot
                            onClicked:  controller.vehicle.rebootVehicle()
                        }
                    }
                }
            }

            // Battery 2 settings - Used when full params are available
            Column {
                id:         batt2FullSettings
                spacing:    _margins / 2
                visible:    _batt2MonitorEnabled && _batt2ParamsAvailable

                QGCLabel {
                    text:       qsTr("电池 2")
                    font.bold:   true
                }

                Rectangle {
                    width:  battery2Loader.x + battery2Loader.width + _margins
                    height: battery2Loader.y + battery2Loader.height + _margins
                    color:  ggcPal.windowShade

                    Loader {
                        id:                 battery2Loader
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        sourceComponent:    batt2FullSettings.visible ? powerSetupComponent : undefined

                        property Fact armVoltMin:       controller.getParameterFact(-1, "r.BATT2_ARM_VOLT", false /* reportMissing */)
                        property Fact battAmpPerVolt:   controller.getParameterFact(-1, "r.BATT2_AMP_PERVLT", false /* reportMissing */)
                        property Fact battAmpOffset:    controller.getParameterFact(-1, "BATT2_AMP_OFFSET", false /* reportMissing */)
                        property Fact battCapacity:     controller.getParameterFact(-1, "BATT2_CAPACITY", false /* reportMissing */)
                        property Fact battCurrPin:      controller.getParameterFact(-1, "BATT2_CURR_PIN", false /* reportMissing */)
                        property Fact battMonitor:      controller.getParameterFact(-1, "BATT2_MONITOR", false /* reportMissing */)
                        property Fact battVoltMult:     controller.getParameterFact(-1, "BATT2_VOLT_MULT", false /* reportMissing */)
                        property Fact battVoltPin:      controller.getParameterFact(-1, "BATT2_VOLT_PIN", false /* reportMissing */)
                        property FactGroup  _batteryFactGroup:  batt2FullSettings.visible ? controller.vehicle.getFactGroup("battery1") : null
                        property Fact vehicleVoltage:   _batteryFactGroup ? _batteryFactGroup.voltage : null
                        property Fact vehicleCurrent:   _batteryFactGroup ? _batteryFactGroup.current : null
                    }
                }
            }

            Column {
                spacing:    _margins / 2
                visible:    _escCalibrationAvailable

                QGCLabel {
                    text:       qsTr("ESC 校准")
                    font.bold:   true
                }

                Rectangle {
                    width:  escCalibrationHolder.x + escCalibrationHolder.width + _margins
                    height: escCalibrationHolder.y + escCalibrationHolder.height + _margins
                    color:  ggcPal.windowShade

                    Column {
                        id:         escCalibrationHolder
                        x:          _margins
                        y:          _margins
                        spacing:    _margins

                        Column {
                            spacing: _margins

                            QGCLabel {
                                text:   qsTr("警告：校准前请移除道具！")
                                color:  qgcPal.warningText
                            }

                            Row {
                                spacing: _margins

                                QGCButton {
                                    text: qsTr("校准")
                                    enabled:    _escCalibration && _escCalibration.rawValue === 0
                                    onClicked:  if(_escCalibration) _escCalibration.rawValue = 3
                                }

                                Column {
                                    enabled: _escCalibration && _escCalibration.rawValue === 3
                                    QGCLabel { text:   _escCalibration ? (_escCalibration.rawValue === 3 ? qsTr("现在请执行以下步骤:") : qsTr("点击校准开始，然后:")) : "" }
                                    QGCLabel { text:   qsTr("- 断开USB和电池，使飞控关闭") }
                                    QGCLabel { text:   qsTr("- 连接电池") }
                                    QGCLabel { text:   qsTr("- 播放蜂鸣音 (如果飞控有蜂鸣器)") }
                                    QGCLabel { text:   qsTr("- 如果使用有安全按钮的飞控，按下按钮直到显示为红色") }
                                    QGCLabel { text:   qsTr("- 听到音乐然后两个嘟嘟声") }
                                    QGCLabel { text:   qsTr("- 稍后你应该听到一个数字的 嘟嘟声 (每个电池单元格一个)") }
                                    QGCLabel { text:   qsTr("- 最后你应该听到一个长的 嘟嘟声 指示校准完成") }
                                    QGCLabel { text:   qsTr("- 断开电池并正常启动") }
                                }
                            }
                        }
                    }
                }
            }
        } // Flow
    } // Component - powerPageComponent

    Component {
        id: powerSetupComponent

        Column {
            spacing: _margins

            property real _margins:         ScreenTools.defaultFontPixelHeight / 2
            property bool _showAdvanced:    sensorCombo.currentIndex === sensorModel.count - 1
            property real _fieldWidth:      ScreenTools.defaultFontPixelWidth * 25

            Component.onCompleted: calcSensor()

            function calcSensor() {
                for (var i=0; i<sensorModel.count - 1; i++) {
                    if (sensorModel.get(i).voltPin === battVoltPin.value &&
                            sensorModel.get(i).currPin === battCurrPin.value &&
                            Math.abs(sensorModel.get(i).voltMult - battVoltMult.value) < 0.001 &&
                            Math.abs(sensorModel.get(i).ampPerVolt - battAmpPerVolt.value) < 0.0001 &&
                            Math.abs(sensorModel.get(i).ampOffset - battAmpOffset.value) < 0.0001) {
                        sensorCombo.currentIndex = i
                        return
                    }
                }
                sensorCombo.currentIndex = sensorModel.count - 1
            }

            QGCPalette { id: qgcPal; colorGroupEnabled: true }

            ListModel {
                id: sensorModel

                ListElement {
                    text:       qsTr("电源模块 90A")
                    voltPin:    2
                    currPin:    3
                    voltMult:   10.1
                    ampPerVolt: 17.0
                    ampOffset:  0
                }

                ListElement {
                    text:       qsTr("电源模块 HV")
                    voltPin:    2
                    currPin:    3
                    voltMult:   12.02
                    ampPerVolt: 39.877
                    ampOffset:  0
                }

                ListElement {
                    text:       qsTr("3DR Iris")
                    voltPin:    2
                    currPin:    3
                    voltMult:   12.02
                    ampPerVolt: 17.0
                    ampOffset:  0
                }

                ListElement {
                    text:       qsTr("蓝色机器人电源感应模块")
                    voltPin:    2
                    currPin:    3
                    voltMult:   11.000
                    ampPerVolt: 37.8788
                    ampOffset:  0.330
                }

                ListElement {
                    text:       qsTr("带蓝色机器人电源感应模块的导航器")
                    voltPin:    5
                    currPin:    4
                    voltMult:   11.000
                    ampPerVolt: 37.8788
                    ampOffset:  0.330
                }

                ListElement {
                    text:       qsTr("其他")
                }
            }


            GridLayout {
                columns:        3
                rowSpacing:     _margins
                columnSpacing:  _margins

                QGCLabel { text: qsTr("电池监控:") }

                FactComboBox {
                    id:         monitorCombo
                    fact:       battMonitor
                    indexModel: false
                    sizeToContents: true
                }

                QGCLabel {
                    Layout.row:     1
                    Layout.column:  0
                    text:           qsTr("电池容量:")
                }

                FactTextField {
                    id:     capacityField
                    width:  _fieldWidth
                    fact:   battCapacity
                }

                QGCLabel {
                    Layout.row:     2
                    Layout.column:  0
                    text:           qsTr("最小启动电压:")
                }

                FactTextField {
                    id:     armVoltField
                    width:  _fieldWidth
                    fact:   armVoltMin
                }

                QGCLabel {
                    Layout.row:     3
                    Layout.column:  0
                    text:           qsTr("电源传感器:")
                }

                QGCComboBox {
                    id:                     sensorCombo
                    Layout.minimumWidth:    _fieldWidth
                    model:                  sensorModel
                    textRole:               "text"

                    onActivated: (index) => {
                        if (index < sensorModel.count - 1) {
                            battVoltPin.value = sensorModel.get(index).voltPin
                            battCurrPin.value = sensorModel.get(index).currPin
                            battVoltMult.value = sensorModel.get(index).voltMult
                            battAmpPerVolt.value = sensorModel.get(index).ampPerVolt
                            battAmpOffset.value = sensorModel.get(index).ampOffset
                        } else {

                        }
                    }
                }

                QGCLabel {
                    Layout.row:     4
                    Layout.column:  0
                    text:           qsTr("电流引脚:") 
                    visible:        _showAdvanced
                }

                FactComboBox {
                    Layout.minimumWidth:    _fieldWidth
                    fact:                   battCurrPin
                    indexModel:             false
                    visible:                _showAdvanced
                    sizeToContents:         true
                }

                QGCLabel {
                    Layout.row:     5
                    Layout.column:  0
                    text:           qsTr("电压引脚:")
                    visible:        _showAdvanced
                }

                FactComboBox {
                    Layout.minimumWidth:    _fieldWidth
                    fact:                   battVoltPin
                    indexModel:             false
                    visible:                _showAdvanced
                    sizeToContents:         true
                }

                QGCLabel {
                    Layout.row:     6
                    Layout.column:  0
                    text:           qsTr("电压倍增器:")
                    visible:        _showAdvanced
                }

                FactTextField {
                    width:      _fieldWidth
                    fact:       battVoltMult
                    visible:    _showAdvanced
                }

                QGCButton {
                    text:       qsTr("计算")
                    visible:    _showAdvanced
                    onClicked:  calcVoltageMultiplierDlgComponent.createObject(mainWindow, { vehicleVoltageFact: vehicleVoltage, battVoltMultFact: battVoltMult }).open()
                }

                QGCLabel {
                    Layout.columnSpan:  3
                    Layout.fillWidth:   true
                    font.pointSize:     ScreenTools.smallFontPointSize
                    wrapMode:           Text.WordWrap
                    text:               qsTr("如果您使用电池监测器，可以调整电压倍增器来校正报告的电池电压。如果车辆报告的电池电压与使用电压表从外部读取的电压差异较大，您可以调整电压倍增器的值来校正差异。点击“计算”按钮以获取计算新值的帮助。")
                    visible:            _showAdvanced
                }

                QGCLabel {
                    text:       qsTr("电流/电压:")
                    visible:    _showAdvanced
                }

                FactTextField {
                    width:      _fieldWidth
                    fact:       battAmpPerVolt
                    visible:    _showAdvanced
                }

                QGCButton {
                    text:       qsTr("计算")
                    visible:    _showAdvanced
                    onClicked:  calcAmpsPerVoltDlgComponent.createObject(mainWindow, { vehicleCurrentFact: vehicleCurrent, battAmpPerVoltFact: battAmpPerVolt }).open()
                }

                QGCLabel {
                    Layout.columnSpan:  3
                    Layout.fillWidth:   true
                    font.pointSize:     ScreenTools.smallFontPointSize
                    wrapMode:           Text.WordWrap
                    text:               qsTr("如果车辆报告的电流消耗与使用电流表外部读取的电流值差异很大，您可以调整每伏安培值来纠正。点击“计算”按钮以获取计算新值的帮助。")
                    visible:            _showAdvanced
                }

                QGCLabel {
                    text:       qsTr("电流偏移:")
                    visible:    _showAdvanced
                }

                FactTextField {
                    width:      _fieldWidth
                    fact:       battAmpOffset
                    visible:    _showAdvanced
                }

                QGCLabel {
                    Layout.columnSpan:  3
                    Layout.fillWidth:   true
                    font.pointSize:     ScreenTools.smallFontPointSize
                    wrapMode:           Text.WordWrap
                    text:               qsTr("如果车辆报告的电流消耗与使用电流表外部读取的电流值差异很大，您可以调整电流偏移值来纠正。它应该等于传感器报告的电流为零时的电压值。")
                    visible:            _showAdvanced
                }

            } // GridLayout
        } // Column
    } // Component - powerSetupComponent

    Component {
        id: calcVoltageMultiplierDlgComponent

        QGCPopupDialog {
            title:      qsTr("计算电压倍增器")
            buttons:    Dialog.Close

            property Fact vehicleVoltageFact
            property Fact battVoltMultFact

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.preferredWidth:  gridLayout.width
                    wrapMode:               Text.WordWrap
                    text:                   qsTr("使用外部电压表测量电池电压并输入值。点击“计算”按钮设置新的调整后的电压倍增器。")
                }

                GridLayout {
                    id:         gridLayout
                    columns:    2

                    QGCLabel {
                        text: qsTr("测量电压:")
                    }
                    QGCTextField { id: measuredVoltage }

                    QGCLabel { text: qsTr("电压:") }
                    FactLabel { fact: vehicleVoltageFact }

                    QGCLabel { text: qsTr("电压倍增器:") }
                    FactLabel { fact: battVoltMultFact }
                }

                QGCButton {
                    text: qsTr("计算并设置")

                    onClicked:  {
                        var measuredVoltageValue = parseFloat(measuredVoltage.text)
                        if (measuredVoltageValue === 0 || isNaN(measuredVoltageValue) || !vehicleVoltageFact || !battVoltMultFact) {
                            return
                        }
                        var newVoltageMultiplier = (vehicleVoltageFact.value !== 0) ? (measuredVoltageValue * battVoltMultFact.value) / vehicleVoltageFact.value : 0
                        if (newVoltageMultiplier > 0) {
                            battVoltMultFact.value = newVoltageMultiplier
                        }
                    }
                }
            }
        }
    }

    Component {
        id: calcAmpsPerVoltDlgComponent

        QGCPopupDialog {
            title:      qsTr("计算每伏安培")
            buttons:    Dialog.Close

            property Fact vehicleCurrentFact
            property Fact battAmpPerVoltFact

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.preferredWidth:  gridLayout.width
                    wrapMode:               Text.WordWrap
                    text:                   qsTr("使用外部电流表测量电流消耗并输入值。点击“计算”按钮设置新的每伏安培值。")
                }

                GridLayout {
                    id:         gridLayout
                    columns:    2

                    QGCLabel {
                        text: qsTr("测量电流:")
                    }
                    QGCTextField { id: measuredCurrent }

                    QGCLabel { text: qsTr("电流:") }
                    FactLabel { fact: vehicleCurrentFact }

                    QGCLabel { text: qsTr("每伏安培:") }
                    FactLabel { fact: battAmpPerVoltFact }
                }

                QGCButton {
                    text: qsTr("计算并设置")

                    onClicked:  {
                        var measuredCurrentValue = parseFloat(measuredCurrent.text)
                        if (measuredCurrentValue === 0 || isNaN(measuredCurrentValue) || !vehicleCurrentFact || !battAmpPerVoltFact) {
                            return
                        }
                        var newAmpsPerVolt = (vehicleCurrentFact.value !== 0) ? (measuredCurrentValue * battAmpPerVoltFact.value) / vehicleCurrentFact.value : 0
                        if (newAmpsPerVolt !== 0) {
                            battAmpPerVoltFact.value = newAmpsPerVolt
                        }
                    }
                }
            }
        }
    }
} // SetupPage
