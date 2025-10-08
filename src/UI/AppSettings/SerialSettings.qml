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
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

ColumnLayout {
    spacing: _rowSpacing

    function saveSettings() {
        // No Need
    }
    GridLayout {
        columns:        2
        rowSpacing:     _rowSpacing
        columnSpacing:  _colSpacing

        // 串口选择
        QGCLabel { text: qsTr("串行端口") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // 下拉框
            QGCComboBox {
                id: commPortCombo
                Layout.preferredWidth: _secondColumnWidth * 0.6

                Component.onCompleted: {
                    var serialPorts = []

                    for (var i=0; i<QGroundControl.linkManager.serialPortStrings.length; i++) {
                        serialPorts.push(QGroundControl.linkManager.serialPortStrings[i])
                    }

                    if (subEditConfig.portName && serialPorts.indexOf(subEditConfig.portName) === -1) {
                        serialPorts.push(subEditConfig.portName)
                    }

                    serialPorts.push(qsTr("自定义端口…"))
                    commPortCombo.model = serialPorts

                    var index = serialPorts.indexOf(subEditConfig.portName)
                    if (index === -1) index = 0
                    commPortCombo.currentIndex = index
                }

                onActivated: (index) => {
                    if (index === commPortCombo.model.length - 1) {
                        customPortField.visible = true
                        customPortField.forceActiveFocus()
                    } else {
                        subEditConfig.portName = commPortCombo.textAt(index)
                        customPortField.visible = false
                    }
                }
            }

            // 自定义输入框
            TextField {
                id: customPortField
                Layout.preferredWidth: _secondColumnWidth * 0.35
                visible: false
                placeholderText: qsTr("请输入串口名称")
                text: subEditConfig.portName

                onTextChanged: {
                    subEditConfig.portName = text
                }
            }
        }

    // GridLayout {
    //     columns:        2
    //     rowSpacing:     _rowSpacing
    //     columnSpacing:  _colSpacing
    //
    //     // 串口选择
    //     QGCLabel { text: qsTr("串行端口") }
    //     Column {
    //         Layout.preferredWidth: _secondColumnWidth
    //         spacing: 6
    //
    //         QGCComboBox {
    //             id:                     commPortCombo
    //             Layout.preferredWidth:  _secondColumnWidth
    //             enabled:                QGroundControl.linkManager.serialPorts.length > 0
    //
    //             onActivated: (index) => {
    //                 if (index !== -1) {
    //                     if (index >= QGroundControl.linkManager.serialPortStrings.length) {
    //                         // 选择了额外添加的条目
    //                         subEditConfig.portName = commPortCombo.textAt(index)
    //                     } else {
    //                         subEditConfig.portName = QGroundControl.linkManager.serialPorts[index]
    //                     }
    //                 }
    //             }
    //
    //             Component.onCompleted: {
    //                 var index = -1
    //                 var serialPorts = []
    //                 if (QGroundControl.linkManager.serialPortStrings.length !== 0) {
    //                     for (var i=0; i<QGroundControl.linkManager.serialPortStrings.length; i++) {
    //                         serialPorts.push(QGroundControl.linkManager.serialPortStrings[i])
    //                     }
    //                     if (subEditConfig.portDisplayName === "" &&
    //                         QGroundControl.linkManager.serialPorts.length > 0) {
    //                         subEditConfig.portName = QGroundControl.linkManager.serialPorts[0]
    //                     }
    //                     index = serialPorts.indexOf(subEditConfig.portDisplayName)
    //                     if (index === -1) {
    //                         serialPorts.push(subEditConfig.portName)
    //                         index = serialPorts.indexOf(subEditConfig.portName)
    //                     }
    //                 }
    //                 if (serialPorts.length === 0) {
    //                     serialPorts = [ qsTr("无可用端口") ]
    //                     index = 0
    //                 }
    //                 commPortCombo.model = serialPorts
    //                 commPortCombo.currentIndex = index
    //             }
    //         }
    //
    //         // 无可用端口时显示输入框
    //         TextField {
    //             id: customPortField
    //             visible: commPortCombo.model.length === 1 &&
    //                 commPortCombo.model[0] === qsTr("无可用端口")
    //             Layout.preferredWidth: _secondColumnWidth
    //             placeholderText: qsTr("请输入自定义串口名，例如 ttyS1 或 ACM0")
    //             text: subEditConfig.portName
    //
    //             onTextChanged: {
    //                 subEditConfig.portName = text
    //             }
    //         }
    //     }

        // 波特率
        QGCLabel { text: qsTr("波特率") }
        QGCComboBox {
            id:                     baudCombo
            Layout.preferredWidth:  _secondColumnWidth
            model:                  QGroundControl.linkManager.serialBaudRates

            onActivated: (index) => {
                if (index !== -1) {
                    subEditConfig.baud = parseInt(QGroundControl.linkManager.serialBaudRates[index])
                }
            }

            Component.onCompleted: {
                var baud = "57600"
                if (subEditConfig !== null) {
                    baud = subEditConfig.baud.toString()
                }
                var index = baudCombo.find(baud)
                if (index === -1) {
                    console.warn(qsTr("波特率不在组合框中"), baud)
                } else {
                    baudCombo.currentIndex = index
                }
            }
        }
    }

    // GridLayout {
    //     columns:        2
    //     rowSpacing:     _rowSpacing
    //     columnSpacing:  _colSpacing
    //
    //     QGCLabel { text: qsTr("串行端口") }
    //     QGCComboBox {
    //         id:                     commPortCombo
    //         Layout.preferredWidth:  _secondColumnWidth
    //         enabled:                QGroundControl.linkManager.serialPorts.length > 0
    //
    //         onActivated: (index) => {
    //             if (index != -1) {
    //                 if (index >= QGroundControl.linkManager.serialPortStrings.length) {
    //                     // This item was adding at the end, must use added text as name
    //                     subEditConfig.portName = commPortCombo.textAt(index)
    //                 } else {
    //                     subEditConfig.portName = QGroundControl.linkManager.serialPorts[index]
    //                 }
    //             }
    //         }
    //
    //         Component.onCompleted: {
    //             var index = -1
    //             var serialPorts = [ ]
    //             if (QGroundControl.linkManager.serialPortStrings.length !== 0) {
    //                 for (var i=0; i<QGroundControl.linkManager.serialPortStrings.length; i++) {
    //                     serialPorts.push(QGroundControl.linkManager.serialPortStrings[i])
    //                 }
    //                 if (subEditConfig.portDisplayName === "" && QGroundControl.linkManager.serialPorts.length > 0) {
    //                     subEditConfig.portName = QGroundControl.linkManager.serialPorts[0]
    //                 }
    //                 index = serialPorts.indexOf(subEditConfig.portDisplayName)
    //                 if (index === -1) {
    //                     serialPorts.push(subEditConfig.portName)
    //                     index = serialPorts.indexOf(subEditConfig.portName)
    //                 }
    //             }
    //             if (serialPorts.length === 0) {
    //                 serialPorts = [ qsTr("无可用端口") ]
    //                 index = 0
    //             }
    //             commPortCombo.model = serialPorts
    //             commPortCombo.currentIndex = index
    //         }
    //     }
    //
    //     QGCLabel { text: qsTr("波特率") }
    //     QGCComboBox {
    //         id:                     baudCombo
    //         Layout.preferredWidth:  _secondColumnWidth
    //         model:                  QGroundControl.linkManager.serialBaudRates
    //
    //         onActivated: (index) => {
    //             if (index != -1) {
    //                 subEditConfig.baud = parseInt(QGroundControl.linkManager.serialBaudRates[index])
    //             }
    //         }
    //
    //         Component.onCompleted: {
    //             var baud = "57600"
    //             if(subEditConfig != null) {
    //                 baud = subEditConfig.baud.toString()
    //             }
    //             var index = baudCombo.find(baud)
    //             if (index === -1) {
    //                 console.warn(qsTr("波特率不在组合框中"), baud)
    //             } else {
    //                 baudCombo.currentIndex = index
    //             }
    //         }
    //     }
    // }

    QGCCheckBox {
        id:         advancedSettings
        text:       qsTr("高级设置")
        checked:    false
    }

    GridLayout {
        columns:        2
        rowSpacing:     _rowSpacing
        columnSpacing:  _colSpacing
        visible:        advancedSettings.checked

        QGCCheckBox {
            Layout.columnSpan:  2
            text:               qsTr("启用流控制")
            checked:            subEditConfig.flowControl !== 0
            onCheckedChanged:   subEditConfig.flowControl = checked ? 1 : 0
        }

        QGCLabel { text: qsTr("校验位") }
        QGCComboBox {
            Layout.preferredWidth:  _secondColumnWidth
            model:                  [qsTr("无"), qsTr("偶数"), qsTr("奇数")]

            onActivated: (index) => {
                // Hard coded values from qserialport.h
                switch (index) {
                case 0:
                    subEditConfig.parity = 0
                    break
                case 1:
                    subEditConfig.parity = 2
                    break
                case 2:
                    subEditConfig.parity = 3
                    break
                }
            }

            Component.onCompleted: {
                switch (subEditConfig.parity) {
                case 0:
                    currentIndex = 0
                    break
                case 2:
                    currentIndex = 1
                    break
                case 3:
                    currentIndex = 2
                    break
                default:
                    console.warn("Unknown parity", subEditConfig.parity)
                    break
                }
            }
        }

        QGCLabel { text: qsTr("数据位") }
        QGCComboBox {
            Layout.preferredWidth:  _secondColumnWidth
            model:                  [ "5", "6", "7", "8" ]
            currentIndex:           Math.max(Math.min(subEditConfig.dataBits - 5, 3), 0)
            onActivated: (index) => { subEditConfig.dataBits = index + 5 }
        }

        QGCLabel { text: qsTr("停止位") }
        QGCComboBox {
            Layout.preferredWidth:  _secondColumnWidth
            model:                  [ "1", "2" ]
            currentIndex:           Math.max(Math.min(subEditConfig.stopBits - 1, 1), 0)
            onActivated: (index) => { subEditConfig.stopBits = index + 1 }
        }
    }
}
