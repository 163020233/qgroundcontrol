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

import QGroundControl
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Controllers
import QGroundControl.AutoPilotPlugins.PX4

// Note: Only the _SOURCE parameter can be assumed to be always available. The remainder of the parameters
// may or may not be available depending on the _SOURCE setting.
SetupPage {
    id:             powerPage
    pageComponent:  pageComponent

    Component {
        id: pageComponent

        Item {
            width:  Math.max(availableWidth, innerColumn.width)
            height: innerColumn.height

            readonly property string    _highlightPrefix:           "<font color=\"" + qgcPal.warningText + "\">"
            readonly property string    _highlightSuffix:           "</font>"

            property int    _textEditWidth:             ScreenTools.defaultFontPixelWidth * 8
            property Fact   _uavcanEnable:              controller.getParameterFact(-1, "UAVCAN_ENABLE", false)
            property int    _indexedBatteryParamCount:  getIndexedBatteryParamCount()

            function getIndexedBatteryParamCount() {
                var batteryIndex = 1
                do {
                    if (!controller.parameterExists(-1, "BAT#_SOURCE".replace("#", batteryIndex))) {
                        return batteryIndex - 1
                    }
                    batteryIndex++
                } while (true)
            }

            PowerComponentController {
                id:                     controller
                onOldFirmware:          mainWindow.showMessageDialog(qsTr("电池校准"),           qsTr("%1 不支持电池校准，您需要升级到最新版本的 %1 才能进行电池校准.").arg(QGroundControl.appName))
                onNewerFirmware:        mainWindow.showMessageDialog(qsTr("电池校准"),           qsTr("%1 不支持电池校准，您需要升级到最新版本的 %1 才能进行电池校准.").arg(QGroundControl.appName))
                onDisconnectBattery:    mainWindow.showMessageDialog(qsTr("电池校准失败"),    qsTr("执行 ESC 校准前必须断开电池连接。请断开电池连接并重试。"))
                onConnectBattery:       escCalibrationDlgComponent.createObject(mainWindow).open()
            }

            ColumnLayout {
                id:                         innerColumn
                anchors.horizontalCenter:   parent.horizontalCenter
                spacing:                    ScreenTools.defaultFontPixelHeight

                function drawArrowhead(ctx, x, y, radians)
                {
                    ctx.save();
                    ctx.beginPath();
                    ctx.translate(x,y);
                    ctx.rotate(radians);
                    ctx.moveTo(0,0);
                    ctx.lineTo(5,10);
                    ctx.lineTo(-5,10);
                    ctx.closePath();
                    ctx.restore();
                    ctx.fill();
                }

                function drawLineWithArrow(ctx, x1, y1, x2, y2)
                {
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(x2, y2);
                    ctx.stroke();
                    var rd = Math.atan((y2 - y1) / (x2 - x1));
                    rd += ((x2 > x1) ? 90 : -90) * Math.PI/180;
                    drawArrowhead(ctx, x2, y2, rd);
                }

                Repeater {
                    id:     batterySetupRepeater
                    model:  _indexedBatteryParamCount

                    Loader {
                        sourceComponent: batterySetupComponent

                        property int    batteryIndex:           index + 1
                        property bool   showBatteryIndex:       batterySetupRepeater.count > 1
                    }
                }


                QGCGroupBox {
                    Layout.fillWidth:   true
                    title:              qsTr("电池校准")

                    ColumnLayout {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        spacing:        ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            color:              qgcPal.warningText
                            wrapMode:           Text.WordWrap
                            text:               qsTr("警告：在执行电池校准前，必须先从飞行器上拆下所有螺旋桨。")
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text: qsTr("执行电池校准前，必须使用 USB 连接。")
                        }

                        QGCButton {
                            text:       qsTr("校准")
                            width:      ScreenTools.defaultFontPixelWidth * 20
                            onClicked:  controller.calibrateEsc()
                        }
                    }
                }

                QGCCheckBox {
                    id:         showUAVCAN
                    text:       qsTr("显示 UAVCAN 配置")
                    checked:    _uavcanEnable ? _uavcanEnable.rawValue !== 0 : false
                }

                QGCGroupBox {
                    Layout.fillWidth:       true
                    title:                  qsTr("UAVCAN 总线配置")
                    visible:                showUAVCAN.checked

                    Row {
                        id:         uavCanConfigRow
                        spacing:    ScreenTools.defaultFontPixelWidth

                        FactComboBox {
                            id:                 _uavcanEnabledCheckBox
                            width:              ScreenTools.defaultFontPixelWidth * 20
                            fact:               _uavcanEnable
                            indexModel:         false
                        }

                        QGCLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text:                   qsTr("需要重启")
                        }
                    }
                }

                QGCGroupBox {
                    Layout.fillWidth:       true
                    title:                  qsTr("UAVCAN 电机索引和方向赋值")
                    visible:                showUAVCAN.checked

                    ColumnLayout {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        spacing:        ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            wrapMode:           Text.WordWrap
                            color:              qgcPal.warningText
                            text:               qsTr("警告：在执行 UAVCAN 配置前，必须先从飞行器上拆下所有螺旋桨。")
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            wrapMode:           Text.WordWrap
                            text:               qsTr("ESC 参数在赋值后才会在编辑器中可见。")
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            wrapMode:           Text.WordWrap
                            text:               qsTr("开始赋值过程后，按照电机索引的顺序，将每个电机旋转到其正确的方向。")
                            Layout.fillWidth:   true
                        }

                        QGCButton {
                            text:       qsTr("开始赋值")
                            width:      ScreenTools.defaultFontPixelWidth * 20
                            onClicked:  controller.startBusConfigureActuators()
                        }

                        QGCButton {
                            text:       qsTr("停止赋值")
                            width:      ScreenTools.defaultFontPixelWidth * 20
                            onClicked:  controller.stopBusConfigureActuators()
                        }
                    }
                }

            } // Column

            Component {
                id: batterySetupComponent

                QGCGroupBox {
                    Layout.fillWidth:   true
                    title:              qsTr("电池 ") + (showBatteryIndex ? batteryIndex : "")

                    property var _controller:   controller
                    property int _batteryIndex: batteryIndex

                    BatteryParams {
                        id:             batParams
                        controller:     _controller
                        batteryIndex:   _batteryIndex
                    }

                    property bool battNumCellsAvailable:        batParams.battNumCellsAvailable
                    property bool battHighVoltAvailable:        batParams.battHighVoltAvailable
                    property bool battLowVoltAvailable:         batParams.battLowVoltAvailable
                    property bool battVoltLoadDropAvailable:    batParams.battVoltLoadDropAvailable
                    property bool battVoltageDividerAvailable:  batParams.battVoltageDividerAvailable
                    property bool battAmpsPerVoltAvailable:     batParams.battAmpsPerVoltAvailable

                    property Fact battSource:           batParams.battSource
                    property Fact battNumCells:         batParams.battNumCells
                    property Fact battHighVolt:         batParams.battHighVolt
                    property Fact battLowVolt:          batParams.battLowVolt
                    property Fact battVoltLoadDrop:     batParams.battVoltLoadDrop
                    property Fact battVoltageDivider:   batParams.battVoltageDivider
                    property Fact battAmpsPerVolt:      batParams.battAmpsPerVolt

                    function getBatteryImage() {
                        switch(battNumCells.value) {
                        case 1:  return "/qmlimages/PowerComponentBattery_01cell.svg";
                        case 2:  return "/qmlimages/PowerComponentBattery_02cell.svg"
                        case 3:  return "/qmlimages/PowerComponentBattery_03cell.svg"
                        case 4:  return "/qmlimages/PowerComponentBattery_04cell.svg"
                        case 5:  return "/qmlimages/PowerComponentBattery_05cell.svg"
                        case 6:  return "/qmlimages/PowerComponentBattery_06cell.svg"
                        default: return "/qmlimages/PowerComponentBattery_01cell.svg";
                        }
                    }

                    ColumnLayout {

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth
                            visible: battSource.rawValue == -1

                            QGCLabel { text:  qsTr("电池源") }
                            FactComboBox {
                                width:          _textEditWidth
                                fact:           battSource
                                indexModel:     false
                                sizeToContents: true
                            }
                        }

                        GridLayout {
                            id:             batteryGrid
                            columns:        5
                            columnSpacing:  ScreenTools.defaultFontPixelWidth
                            visible:        battSource.rawValue != -1

                            QGCLabel { text:  qsTr("电池源") }
                            FactComboBox {
                                width:          _textEditWidth
                                fact:           battSource
                                indexModel:     false
                                sizeToContents: true
                            }

                            QGCColoredImage {
                                id:                     battImage
                                Layout.rowSpan:         4
                                width:                  height * 0.75
                                height:                 100
                                sourceSize.height:      height
                                fillMode:               Image.PreserveAspectFit
                                smooth:                 true
                                color:                  qgcPal.text
                                cache:                  false
                                source:                 getBatteryImage(batteryIndex)
                                visible:                battNumCellsAvailable && battLowVoltAvailable && battHighVoltAvailable
                            }

                            Item { 
                                width:              1
                                height:             1
                                Layout.columnSpan:  battImage.visible ? 2 : 3
                            }

                            QGCLabel { 
                                text:  qsTr("电池单元格数量") 
                                visible: battNumCellsAvailable
                            }
                            FactTextField {
                                width:      _textEditWidth
                                fact:       battNumCells
                                showUnits:  true
                                visible:    battNumCellsAvailable
                            }
                            QGCLabel { 
                                text:       qsTr("电池最大容量:")
                                visible:    battImage.visible 
                            }
                            QGCLabel { 
                                text:       visible ? (battNumCells.value * battHighVolt.value).toFixed(1) + ' V' : ""
                                visible:    battImage.visible 
                            }
                            Item { 
                                width:              1
                                height:             1
                                Layout.columnSpan:  3
                                visible:            !battImage.visible
                            }

                            QGCLabel { 
                                text:       qsTr("空电压（每节电池）") 
                                visible:    battLowVoltAvailable
                            }
                            FactTextField {
                                width:      _textEditWidth
                                fact:       battLowVolt
                                showUnits:  true
                                visible:    battLowVoltAvailable
                            }
                            QGCLabel { 
                                text:       qsTr("电池最小电压:") 
                                visible:    battImage.visible
                            }
                            QGCLabel { 
                                text:       visible ? (battNumCells.value * battLowVolt.value).toFixed(1) + ' V' : ""
                                visible:    battImage.visible
                            }
                            Item { 
                                width:              1
                                height:             1
                                Layout.columnSpan:  3
                                visible:            battLowVoltAvailable && !battImage.visible
                            }

                            QGCLabel { 
                                text:       qsTr("电池最大电压（每节电池）") 
                                visible:    battHighVoltAvailable
                            }
                            FactTextField {
                                width:      _textEditWidth
                                fact:       battHighVolt
                                showUnits:  true
                                visible:    battHighVoltAvailable
                            }
                            Item { 
                                width:              1
                                height:             1
                                Layout.columnSpan:  battImage.visible ? 2 : 3
                                visible:            battHighVoltAvailable
                            }

                            QGCLabel {
                                text:       qsTr("分压器")
                                visible:    battVoltageDividerAvailable
                            }
                            FactTextField {
                                fact:       battVoltageDivider
                                visible:    battVoltageDividerAvailable
                            }
                            QGCButton {
                                text:       qsTr("计算")
                                visible:    battVoltageDividerAvailable
                                onClicked:  calcVoltageDividerDlgComponent.createObject(mainWindow, { batteryIndex: _batteryIndex }).open()
                            }
                            Item { width: 1; height: 1; Layout.columnSpan: 2; visible: battVoltageDividerAvailable }

                            QGCLabel {
                                Layout.columnSpan:  batteryGrid.columns
                                Layout.fillWidth:   true
                                font.pointSize:     ScreenTools.smallFontPointSize
                                wrapMode:           Text.WordWrap
                                text:               qsTr("如果设备报告的电池电压与使用电压表从外部读取的电压有很大差异，您可以调整电压倍增器的值来纠正这个问题。") +
                                                    qsTr("点击计算按钮获取计算新值的帮助。")
                                visible:            battVoltageDividerAvailable
                            }
                            QGCLabel {
                                text:       qsTr("电流倍增器")
                                visible:    battAmpsPerVoltAvailable
                            }
                            FactTextField {
                                fact:       battAmpsPerVolt
                                visible:    battAmpsPerVoltAvailable
                            }
                            QGCButton {
                                text:       qsTr("计算")
                                visible:    battAmpsPerVoltAvailable
                                onClicked:  calcAmpsPerVoltDlgComponent.createObject(mainWindow, { batteryIndex: _batteryIndex }).open()
                            }
                            Item { width: 1; height: 1; Layout.columnSpan: 2; visible: battAmpsPerVoltAvailable }

                            QGCLabel {
                                Layout.columnSpan:  batteryGrid.columns
                                Layout.fillWidth:   true
                                font.pointSize:     ScreenTools.smallFontPointSize
                                wrapMode:           Text.WordWrap
                                text:               qsTr("如果设备报告的电池电流与使用电流表从外部读取的电流有很大差异，您可以调整电流倍增器的值来纠正这个问题。") +
                                                    qsTr("点击计算按钮获取计算新值的帮助。")
                                visible:            battAmpsPerVoltAvailable
                            }

                            QGCCheckBox {
                                id:                 showAdvanced
                                Layout.columnSpan:  batteryGrid.columns
                                text:               qsTr("显示高级设置")
                                visible:            battVoltLoadDropAvailable
                            }

                            QGCLabel {
                                text:       qsTr("电压下拉值（每节电池）")
                                visible:    showAdvanced.checked
                            }
                            FactTextField {
                                id:         battDropField
                                fact:       battVoltLoadDrop
                                showUnits:  true
                                visible:    showAdvanced.checked
                            }
                            Item { width: 1; height: 1; Layout.columnSpan: 3; visible: showAdvanced.checked }

                            QGCLabel {
                                Layout.columnSpan:  batteryGrid.columns
                                Layout.fillWidth:   true
                                wrapMode:           Text.WordWrap
                                font.pointSize:     ScreenTools.smallFontPointSize
                                text:               qsTr("电池在高油门下显示更少的电压。输入怠速油门和满油门之间的电压差，除以电池单元格的数量。如果不确定，请保持默认值。 ") +
                                                    _highlightPrefix + qsTr("如果此值设置过高，电池可能会被深度放电并损坏。") + _highlightSuffix
                                visible:            showAdvanced.checked
                            }

                            QGCLabel {
                                text:       qsTr("补偿后的最小电压:")
                                visible:    showAdvanced.checked
                            }
                            QGCLabel {
                                text:       visible ? ((battNumCells.value * battLowVolt.value) - (battNumCells.value * battVoltLoadDrop.value)).toFixed(1) + qsTr(" V") : ""
                                visible:    showAdvanced.checked
                            }
                            Item { width: 1; height: 1; Layout.columnSpan: 3; visible: showAdvanced.checked }
                        } // Grid
                    }
                } // QGCGroupBox - Battery settings
            } // Component - batterySetupComponent

            Component {
                id: calcVoltageDividerDlgComponent

                QGCPopupDialog {
                    title:      qsTr("计算电压倍增器")
                    buttons:    Dialog.Close

                    property alias batteryIndex: batParams.batteryIndex

                    property var        _controller:        controller
                    property FactGroup  _batteryFactGroup:  controller.vehicle.getFactGroup("battery" + (batteryIndex - 1))

                    BatteryParams {
                        id:             batParams
                        controller:     _controller
                    }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            Layout.preferredWidth:  gridLayout.width
                            wrapMode:               Text.WordWrap
                            text:                   qsTr("使用外部电压表测量电池电压，并在下面输入值。点击计算设置新的电压倍增器。")
                        }

                        GridLayout {
                            id:         gridLayout
                            columns:    2

                            QGCLabel { text: qsTr("测量电压:") }
                            QGCTextField { id: measuredVoltage; numericValuesOnly: true }

                            QGCLabel { text: qsTr("电池电压:") }
                            QGCLabel { text: _batteryFactGroup.voltage.valueString }

                            QGCLabel { text: qsTr("电压倍增器:") }
                            FactLabel { fact: batParams.battVoltageDivider }
                        }

                        QGCButton {
                            text: qsTr("Calculate")

                            onClicked:  {
                                var measuredVoltageValue = parseFloat(measuredVoltage.text)
                                if (measuredVoltageValue === 0 || isNaN(measuredVoltageValue)) {
                                    return
                                }
                                var newVoltageDivider = (measuredVoltageValue * batParams.battVoltageDivider.value) / _batteryFactGroup.voltage.value
                                if (newVoltageDivider > 0) {
                                    batParams.battVoltageDivider.value = newVoltageDivider
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: calcAmpsPerVoltDlgComponent

                QGCPopupDialog {
                    title:      qsTr("Calculate Amps per Volt")
                    buttons:    Dialog.Close

                    property alias batteryIndex: batParams.batteryIndex

                    property var        _controller:        controller
                    property FactGroup  _batteryFactGroup:  controller.vehicle.getFactGroup("battery" + (batteryIndex - 1))

                    BatteryParams {
                        id:             batParams
                        controller:     _controller
                    }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            Layout.preferredWidth:  gridLayout.width
                            wrapMode:               Text.WordWrap
                            text:                   qsTr("使用外部电流表测量电池电流，并在下面输入值。点击计算设置新的电流倍增器。")
                        }

                        GridLayout {
                            id:         gridLayout
                            columns:    2

                            QGCLabel { text: qsTr("测量电流:") }
                            QGCTextField { id: measuredCurrent; numericValuesOnly: true }

                            QGCLabel { text: qsTr("电池电流:") }
                            QGCLabel { text: _batteryFactGroup.current.valueString }

                            QGCLabel { text: qsTr("电流倍增器:") }
                            FactLabel { fact: batParams.battAmpsPerVolt }
                        }

                        QGCButton {
                            text: qsTr("计算")

                            onClicked:  {
                                var measuredCurrentValue = parseFloat(measuredCurrent.text)
                                if (measuredCurrentValue === 0 || isNaN(measuredCurrentValue)) {
                                    return
                                }
                                var newAmpsPerVolt = (measuredCurrentValue * batParams.battAmpsPerVolt.value) / _batteryFactGroup.current.value
                                if (newAmpsPerVolt != 0) {
                                    batParams.battAmpsPerVolt.value = newAmpsPerVolt
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: escCalibrationDlgComponent

                QGCPopupDialog {
                    id:                     escCalibrationDlg
                    title:                  qsTr("ESC 校准")
                    buttons:                Dialog.Ok
                    acceptButtonEnabled:    false

                    Connections {
                        target: controller

                        onBatteryConnected:     textLabel.text = qsTr("正在校准ESC。这将需要几秒钟。")
                        onCalibrationFailed:    { escCalibrationDlg.acceptButtonEnabled = true; textLabel.text = _highlightPrefix + qsTr("ESC 校准失败。 ") + _highlightSuffix + errorMessage }
                        onCalibrationSuccess:   { escCalibrationDlg.acceptButtonEnabled = true; textLabel.text = qsTr("校准完成。您可以现在断开电池。") }
                    }

                    ColumnLayout {
                        QGCLabel {
                            id:                     textLabel
                            wrapMode:               Text.WordWrap
                            text:                   _highlightPrefix + qsTr("警告: 校准前请先拆下 props。") + _highlightSuffix + qsTr(" 连接电池后校准将开始。")
                            Layout.fillWidth:       true
                            Layout.maximumWidth:    mainWindow.width / 2
                        }
                    }
                }
            }
        } // Item
    } // Component
} // SetupPage
