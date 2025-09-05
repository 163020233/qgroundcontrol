// /****************************************************************************
//  *
//  * (c) 2009-2022 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
//  *
//  * QGroundControl is licensed according to the terms in the file
//  * COPYING.md in the root of the source code directory.
//  *
//  ****************************************************************************/
//
/****************************************************************************
 *
 * (c) 2009-2025 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 ****************************************************************************/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.FactSystem
import QGroundControl.FactControls


ToolIndicatorPage {
    id: control
    showExpand: true

    property var _linkManager: QGroundControl.linkManager
    property var linkConfigs: _linkManager.linkConfigurations
    property var editingConfig: null

    RowLayout {
        spacing: 12
        width: 800
        height: 400

        // 左侧列表
        ColumnLayout {
            id: leftColumn
            Layout.fillHeight: true
            width: linkConfigs.count > 0 ? 300 : 150
            spacing: 2

            SettingsGroupLayout {
                heading: qsTr("链接列表")

                // 新建连接按钮
                QGCButton {
                    text: qsTr("新建连接")
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    onClicked: {
                        // 创建一个临时新配置（默认串口，可修改类型）
                        editingConfig = _linkManager.createConfiguration(LinkConfiguration.TypeSerial, "新连接")
                        editingConfig._isNew = true  // 标记新建
                        rightColumn.visible = true
                        refreshRightPanel(editingConfig.linkType)

                        // 设置类型 ComboBox
                        typeCombo.currentIndex = editingConfig.linkType
                    }
                }


                // 没有链接提示
                QGCLabel {
                    text: qsTr("没有配置的链接")
                    visible: linkConfigs.count === 0
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                // 链接列表
                Repeater {
                    model: _linkManager.linkConfigurations
                    delegate: RowLayout {
                        spacing: 6
                        visible: !object.dynamic

                        QGCButton {
                            text: object.name
                            Layout.fillWidth: true
                            // onClicked: {
                            //     editingConfig = object
                            //     refreshRightPanel(editingConfig.linkType)
                            //     // 保存后隐藏右侧面板
                            // }
                        }

                        QGCButton {
                            text: (object.link && object.link.connected) ? qsTr("断开") : qsTr("连接")
                            enabled: !object.dynamic && !object.isAutoConnect
                            onClicked: {
                                if (object.link && object.link.connected) object.link.disconnect()
                                else _linkManager.createConnectedLink(object)
                                // refreshRightPanel(object.linkType)  // 点击连接时右侧显示
                                // 保存后隐藏右侧面板
                                editingConfig = null
                                rightColumn.visible = false
                            }
                        }
                        QGCButton {
                            text: qsTr("编辑")
                            enabled: !(object.link && object.link.connected)   // 已连接时禁止编辑
                            onClicked: {
                                if (editingConfig === object) {
                                    // 再次点击 -> 关闭右侧面板
                                    editingConfig = null
                                    rightColumn.visible = false
                                } else {
                                    // 加载已有配置
                                    editingConfig = object
                                    editingConfig._isNew = false
                                    refreshRightPanel(editingConfig.linkType)

                                    // 强制让右侧的 Loader 重新加载
                                    linkSettingsLoader.active = false
                                    linkSettingsLoader.active = true

                                    rightColumn.visible = true
                                }
                            }

                        }

                        QGCButton {
                            text: qsTr("删除")
                            enabled: !object.link || !object.link.connected   // 已连接时禁用编辑
                            background: Rectangle { color: "#E57373"; radius: 6 }
                            onClicked: {
                                mainWindow.showMessageDialog(
                                    qsTr("删除链接"),
                                    qsTr("确定要删除 '%1' 吗？").arg(object.name),
                                    Dialog.Ok | Dialog.Cancel,
                                        function() {
                                        if (object.link && object.link.connected) object.link.disconnect()
                                        if (editingConfig === object) editingConfig = null
                                        _linkManager.removeConfiguration(object)
                                        // 保存后隐藏右侧面板
                                        editingConfig = null
                                        rightColumn.visible = false
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }

        // 右侧配置面板
        ColumnLayout {
            id: rightColumn
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: ScreenTools.defaultFontPixelHeight / 2
            visible: editingConfig !== null  // 默认隐藏，只有创建或点击左侧显示

            SettingsGroupLayout {
                heading: qsTr("连接配置")

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // 类型选择
                    LabelledComboBox {
                        id: typeCombo
                        label: qsTr("类型")
                        model: _linkManager.linkTypeStrings
                        Layout.fillWidth: true

                        Component.onCompleted: {
                            if (editingConfig) comboBox.currentIndex = editingConfig.linkType
                        }

                        onActivated: (index) => {
                            if (!editingConfig) return

                            if (index !== editingConfig.linkType) {
                                // 保留名称和连接状态
                                var oldName = editingConfig.name
                                var wasNew = editingConfig._isNew
                                var oldConnected = editingConfig.link ? editingConfig.link.connected : false

                                // 创建新类型配置
                                editingConfig = _linkManager.createConfiguration(index, oldName)
                                editingConfig._isNew = wasNew

                                // 如果之前已经连接，保持连接
                                if (oldConnected) _linkManager.createConnectedLink(editingConfig)
                            }

                            refreshRightPanel(index)
                        }
                    }

                    // 名称输入
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth
                        visible: editingConfig ? !editingConfig.dynamic : false

                        QGCLabel { text: qsTr("名称") }
                        QGCTextField {
                            id: nameField
                            Layout.fillWidth: true
                            placeholderText: qsTr("输入名称")
                            text: editingConfig ? editingConfig.name : ""
                            onTextChanged: {
                                if (editingConfig) editingConfig.name = text
                            }
                        }
                    }

                    // Loader 动态加载连接设置
                    Loader {
                        id: linkSettingsLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: true
                        property var subEditConfig: editingConfig
                        onActiveChanged: {
                            if (item) item.subEditConfig = editingConfig
                        }
                    }

                    // 保存按钮逻辑
                    QGCButton {
                        text: qsTr("保存")
                        Layout.fillWidth: true
                        enabled: editingConfig ? !(editingConfig.link && editingConfig.link.connected) : false

                        onClicked: {
                            if (!editingConfig) return

                            // 检查重复
                            var exists = false
                            for (var i = 0; i < linkConfigs.count; i++) {
                                var lc = linkConfigs.get(i)
                                if (lc !== editingConfig &&
                                    lc.name === editingConfig.name &&
                                    lc.linkType === editingConfig.linkType) {
                                    exists = true
                                    break
                                }
                            }
                            if (exists) {
                                mainWindow.showMessageDialog(qsTr("提示"), qsTr("该连接已存在！"), Dialog.Ok)
                                return
                            }

                            if (editingConfig._isNew) {
                                editingConfig.dynamic = false
                                _linkManager.endCreateConfiguration(editingConfig)
                                console.log("新增配置: " + editingConfig.name)
                            } else {
                                console.log("更新配置: " + editingConfig.name)
                            }

                            mainWindow.showMessageDialog(qsTr("提示"), qsTr("保存成功！"), Dialog.Ok)

                            editingConfig = null
                            rightColumn.visible = false
                        }
                    }
                }
            }
        }
    }

    function refreshRightPanel(linkType) {
        switch(linkType) {
            case LinkConfiguration.TypeSerial:
                linkSettingsLoader.source = "qrc:/qml/SerialSettings.qml"; break;
            case LinkConfiguration.TypeUdp:
                linkSettingsLoader.source = "qrc:/qml/UdpSettings.qml"; break;
            case LinkConfiguration.TypeTcp:
                linkSettingsLoader.source = "qrc:/qml/TcpSettings.qml"; break;
            case LinkConfiguration.TypeBluetooth:
                linkSettingsLoader.source = "qrc:/qml/BluetoothSettings.qml"; break;
            default:
                linkSettingsLoader.source = ""
        }
        rightColumn.visible = true  // 确保右侧显示
    }
}

// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
//
// import QGroundControl
// import QGroundControl.Controls
// import QGroundControl.MultiVehicleManager
// import QGroundControl.ScreenTools
// import QGroundControl.Palette
// import QGroundControl.FactSystem
// import QGroundControl.FactControls
//
// ToolIndicatorPage {
//     id: control
//     showExpand: true
//
//     property var _linkManager: QGroundControl.linkManager
//     property var linkConfigs: _linkManager.linkConfigurations
//     property bool noLinks: true
//     property var editingConfig: null
//
//     Component.onCompleted: {
//         // 初始选中第一个非动态链接
//         for (var i = 0; i < linkConfigs.count; i++) {
//             var lc = linkConfigs.get(i)
//             if (!lc.dynamic && !lc.isAutoConnect) {
//                 editingConfig = lc
//                 break
//             }
//         }
//         if (!editingConfig && linkConfigs.count > 0) {
//             editingConfig = linkConfigs.get(0)
//         }
//
//         noLinks = linkConfigs.count === 0
//     }
//
//     RowLayout {
//         spacing: 12
//         width: 800
//         height: 400
//
//         // =====================
//         // 左侧：链接列表 + 新建按钮
//         // =====================
//         ColumnLayout {
//             Layout.preferredWidth: 300
//             Layout.fillHeight: true
//             spacing: 4
//
//             SettingsGroupLayout {
//                 heading: qsTr("链接列表")
//
//                 ColumnLayout {
//                     spacing: 4
//                     Layout.fillWidth: true
//
//                     // 新建连接按钮
//                     QGCButton {
//                         text: qsTr("新建连接")
//                         Layout.fillWidth: true
//                         Layout.preferredHeight: 32
//                         onClicked: {
//                             editingConfig = _linkManager.createConfiguration(LinkConfiguration.TypeSerial, "新连接")
//                             linkSettingsLoader.source = "qrc:/qml/SerialSettings.qml"
//                         }
//                     }
//
//                     // 没有链接提示
//                     QGCLabel {
//                         text: qsTr("没有配置的链接")
//                         visible: linkConfigs.length === 0
//                         font.pixelSize: 14
//                         horizontalAlignment: Text.AlignHCenter
//                         Layout.fillWidth: true
//                         padding: 6
//                     }
//
//                     // 链接列表
//                     Repeater {
//                         model: _linkManager.linkConfigurations
//                         delegate: ColumnLayout {
//                             Layout.fillWidth: true
//                             spacing: 2   // 缩小行间距
//
//                             RowLayout {
//                                 visible: !object.dynamic
//                                 Layout.fillWidth: true
//                                 spacing: 4
//
//                                 QGCButton {
//                                     text: object.name
//                                     Layout.fillWidth: true
//                                     onClicked: {
//                                         editingConfig = object
//                                         switch (editingConfig.linkType) {
//                                             case LinkConfiguration.TypeSerial:
//                                                 linkSettingsLoader.source = "qrc:/qml/SerialSettings.qml";
//                                                 break;
//                                             case LinkConfiguration.TypeUdp:
//                                                 linkSettingsLoader.source = "qrc:/qml/UdpSettings.qml";
//                                                 break;
//                                             case LinkConfiguration.TypeTcp:
//                                                 linkSettingsLoader.source = "qrc:/qml/TcpSettings.qml";
//                                                 break;
//                                             case LinkConfiguration.TypeBluetooth:
//                                                 linkSettingsLoader.source = "qrc:/qml/BluetoothSettings.qml";
//                                                 break;
//                                             default:
//                                                 linkSettingsLoader.source = ""
//                                         }
//                                     }
//                                 }
//
//                                 QGCButton {
//                                     text: (object.link && object.link.connected) ? qsTr("断开") : qsTr("连接")
//                                     Layout.preferredWidth: 60
//                                     onClicked: {
//                                         if (object.link && object.link.connected) object.link.disconnect()
//                                         else _linkManager.createConnectedLink(object)
//                                     }
//                                 }
//
//                                 QGCButton {
//                                     text: qsTr("删除")
//                                     Layout.preferredWidth: 60
//                                     background: Rectangle {
//                                         color: "#E57373"; radius: 6
//                                     }
//                                     onClicked: {
//                                         mainWindow.showMessageDialog(
//                                             qsTr("删除链接"),
//                                             qsTr("确定要删除 '%1' 吗？").arg(object.name),
//                                             Dialog.Ok | Dialog.Cancel,
//                                                 function () {
//                                                 if (object.link && object.link.connected) object.link.disconnect()
//                                                 if (editingConfig === object) {
//                                                     editingConfig = null
//                                                     linkSettingsLoader.source = ""
//                                                 }
//                                                 _linkManager.removeConfiguration(object)
//                                             }
//                                         )
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//         }
        // =====================
        // 右侧：新建/编辑连接配置
        // =====================
//         ColumnLayout {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             spacing: ScreenTools.defaultFontPixelHeight / 2
//
//             SettingsGroupLayout {
//                 heading: qsTr("连接配置")
//
//                 ColumnLayout {
//                     spacing: ScreenTools.defaultFontPixelHeight / 2
//                     Layout.fillWidth: true
//                     Layout.fillHeight: true
//
//                     // 类型选择
//                     LabelledComboBox {
//                         id: typeCombo
//                         label: qsTr("类型")
//                         model: _linkManager.linkTypeStrings
//                         Layout.fillWidth: true
//
//                         Component.onCompleted: {
//                             if (editingConfig) comboBox.currentIndex = editingConfig.linkType
//                         }
//
//                         // 当编辑配置改变时，更新 Loader
//                         onActivated: (index) => {
//                             if (!editingConfig) return
//
//                             if (index !== editingConfig.linkType) {
//                                 // 保留名称和连接状态
//                                 var oldName = editingConfig.name
//                                 editingConfig = _linkManager.createConfiguration(index, oldName)
//                             }
//
//                             // 根据类型刷新 Loader
//                             switch (index) {
//                                 case LinkConfiguration.TypeSerial:
//                                     linkSettingsLoader.source = "qrc:/qml/SerialSettings.qml"
//                                     break
//                                 case LinkConfiguration.TypeUdp:
//                                     linkSettingsLoader.source = "qrc:/qml/UdpSettings.qml"
//                                     break
//                                 case LinkConfiguration.TypeTcp:
//                                     linkSettingsLoader.source = "qrc:/qml/TcpSettings.qml"
//                                     break
//                                 case LinkConfiguration.TypeBluetooth:
//                                     linkSettingsLoader.source = "qrc:/qml/BluetoothSettings.qml"
//                                     break
//                                 default:
//                                     linkSettingsLoader.source = ""
//                             }
//                         }
//                     }
//
//                     // 名称输入
//                     RowLayout {
//                         visible: !object.dynamic
//                         Layout.fillWidth: true
//                         spacing: ScreenTools.defaultFontPixelWidth
//
//                         QGCLabel { text: qsTr("名称") }
//
//                         QGCTextField {
//                             id: nameField
//                             Layout.fillWidth: true
//                             placeholderText: qsTr("输入名称")
//                             text: editingConfig ? editingConfig.name : ""
//
//                             // 实时同步 TextField 和 editingConfig.name
//                             onTextChanged: {
//                                 if (editingConfig) editingConfig.name = text
//                             }
//                         }
//                     }
//
//                     // Loader 动态加载具体连接设置
//                     Loader {
//                         id: linkSettingsLoader
//                         Layout.fillWidth: true
//                         Layout.fillHeight: true
//                         active: true
//                         property var subEditConfig: editingConfig
//
//                         // 使用绑定自动刷新子对象
//                         Binding {
//                             target: linkSettingsLoader
//                             property: "subEditConfig"
//                             value: editingConfig
//                         }
//                     }
//
//                     // 保存按钮
//                     QGCButton {
//                         text: qsTr("保存")
//                         Layout.fillWidth: true
//                         onClicked: {
//                             if (!editingConfig) return
//
//                             editingConfig.dynamic = false
//                             _linkManager.endCreateConfiguration(editingConfig)
//                             console.log("保存配置: " + editingConfig.name)
//                             mainWindow.showMessageDialog(qsTr("提示"), qsTr("保存成功！"), Dialog.Ok)
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }


// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
//
// import QGroundControl
// import QGroundControl.Controls
// import QGroundControl.MultiVehicleManager
// import QGroundControl.ScreenTools
// import QGroundControl.Palette
// import QGroundControl.FactSystem
// import QGroundControl.FactControls
//
// ToolIndicatorPage {
//     id:         control
//     showExpand: true
//
//     property var _linkManager: QGroundControl.linkManager
//     property var editingConfig: _linkManager.createConfiguration(LinkConfiguration.TypeSerial, "新连接")
//
//     property var    linkConfigs:            QGroundControl.linkManager.linkConfigurations
//     property bool   noLinks:                true
//     property var    autoConnectSettings:    QGroundControl.settingsManager.autoConnectSettings
//
//     Component.onCompleted: {
//         for (var i = 0; i < linkConfigs.count; i++) {
//             var linkConfig = linkConfigs.get(i)
//             if (!linkConfig.dynamic && !linkConfig.isAutoConnect) {
//                 noLinks = false
//                 break
//             }
//         }
//     }
//     RowLayout {
//         id: linkConfigContainer
//         spacing: 12
//         width: 800
//         height: 400  // 可根据实际需求调整高度
//
//         // =====================
//         // 右侧：新建/编辑连接
//         // =====================
//         ColumnLayout {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             spacing: ScreenTools.defaultFontPixelHeight / 2
//
//             SettingsGroupLayout {
//                 heading: qsTr("新建/编辑连接")
//
//                 ColumnLayout {
//                     Layout.fillWidth: true
//                     Layout.fillHeight: true
//                     spacing: ScreenTools.defaultFontPixelHeight / 2
//
//                     // 类型选择
//                     LabelledComboBox {
//                         id: typeCombo
//                         label: qsTr("类型")
//                         model: QGroundControl.linkManager.linkTypeStrings
//                         Layout.fillWidth: true
//
//                         Component.onCompleted: {
//                             // 默认选中串口
//                             comboBox.currentIndex = LinkConfiguration.TypeSerial
//                             linkSettingsLoader.source = "qrc:/qml/SerialSettings.qml"
//                         }
//
//
//                         onActivated: (index) => {
//                             if (index !== editingConfig.linkType) {
//                                 var name = nameField.text
//                                 editingConfig = _linkManager.createConfiguration(index, name)
//                                 switch(index) {
//                                     case LinkConfiguration.TypeSerial:
//                                         linkSettingsLoader.source = "qrc:/qml/SerialSettings.qml"
//                                         break
//                                     case LinkConfiguration.TypeUdp:
//                                         linkSettingsLoader.source = "qrc:/qml/UdpSettings.qml"
//                                         break
//                                     case LinkConfiguration.TypeTcp:
//                                         linkSettingsLoader.source = "qrc:/qml/TcpSettings.qml"
//                                         break
//                                     case LinkConfiguration.TypeBluetooth:
//                                         linkSettingsLoader.source = "qrc:/qml/BluetoothSettings.qml"
//                                         break
//                                     default:
//                                         linkSettingsLoader.source = ""
//                                 }
//                             }
//                         }
//                     }
//
//                     // 名称输入
//                     RowLayout {
//                         Layout.fillWidth: true
//                         spacing: ScreenTools.defaultFontPixelWidth
//
//                         QGCLabel { text: qsTr("名称") }
//                         QGCTextField {
//                             id: nameField
//                             Layout.fillWidth: true
//                             text: editingConfig.name
//                             placeholderText: qsTr("输入名称")
//                         }
//                     }
//
//                     // Loader 动态加载具体连接设置
//                     Loader {
//                         id: linkSettingsLoader
//                         Layout.fillWidth: true
//                         Layout.fillHeight: true
//                         active: true
//                         property var subEditConfig: editingConfig
//                         onActiveChanged: {
//                             // 确保 Loader 在对象改变时刷新
//                             if (source) {
//                                 item.subEditConfig = editingConfig
//                             }
//                         }
//                     }
//
//
//                     // 保存按钮
//                     QGCButton {
//                         text: qsTr("保存")
//                         Layout.fillWidth: true
//                         onClicked: {
//                             if (editingConfig) {
//                                 editingConfig.name = nameField.text
//                                 editingConfig.dynamic = false
//                                 QGroundControl.linkManager.endCreateConfiguration(editingConfig)
//                                 console.log("保存配置: " + editingConfig.name)
//
//                                 mainWindow.showMessageDialog(
//                                     qsTr("提示"),
//                                     qsTr("保存成功！"),
//                                     Dialog.Ok
//                                 )
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
//
//     // =====================
//     // 保留原 contentComponent 源码
//     // =====================
//     contentComponent: Component {
//         SettingsGroupLayout {
//             heading: qsTr("选择链接")
//
//             QGCLabel {
//                 text:       qsTr("没有配置的链接")
//                 visible:    noLinks
//             }
//             Repeater {
//                 model: linkConfigs
//
//                 delegate: ColumnLayout {
//                     Layout.fillWidth: true
//                     spacing: 4
//
//                     // 设备名字显示
//                     QGCLabel {
//                         text: object.name
//                         font.bold: true
//                     }
//
//                     // 连接按钮
//                     QGCButton {
//                         Layout.fillWidth: true
//                         visible: !object.dynamic
//
//                         text: (object.link && object.link.connected) ? qsTr("断开连接") : qsTr("连接")
//
//                         background: Rectangle {
//                             color: (object.link && object.link.connected) ? "#E57373" : "#81C784"
//                             radius: 6
//                         }
//
//                         onClicked: {
//                             if (object.link && object.link.connected) {
//                                 object.link.disconnect()
//                             } else {
//                                 QGroundControl.linkManager.createConnectedLink(object)
//                             }
//                             mainWindow.closeIndicatorDrawer()
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }
// contentComponent: Component {
//     SettingsGroupLayout {
//         heading: qsTr("选择链接")
//
//         QGCLabel {
//             text:       qsTr("没有配置的链接")
//             visible:    noLinks
//         }
//         Repeater {
//             model: linkConfigs
//
//             delegate: ColumnLayout {
//                 Layout.fillWidth: true
//                 spacing: 4
//
//                 // 设备名字显示
//                 QGCLabel {
//                     text: object.name
//                     font.bold: true
//                 }
//
//                 // 连接按钮
//                 QGCButton {
//                     Layout.fillWidth: true
//                     visible: !object.dynamic
//
//                     // 按钮文字
//                     text: (object.link && object.link.connected) ? qsTr("断开连接") : qsTr("连接")
//
//                     // 按钮颜色
//                     background: Rectangle {
//                         color: (object.link && object.link.connected) ? "#E57373" : "#81C784"
//                         radius: 6
//                     }
//
//                     onClicked: {
//                         if (object.link && object.link.connected) {
//                             object.link.disconnect()
//                         } else {
//                             QGroundControl.linkManager.createConnectedLink(object)
//                         }
//                         mainWindow.closeIndicatorDrawer()
//                     }
//                 }
//             }
//         }
//     }

// Repeater {
//     model: linkConfigs
//
//     delegate: QGCButton {
//         Layout.fillWidth:   true
//         text:               object.name + (object.link ? " (" + qsTr("已连接") + ")" : "")
//         visible:            !object.dynamic
//         enabled:            !object.link
//         autoExclusive:      true
//
//         onClicked: {
//             QGroundControl.linkManager.createConnectedLink(object)
//             mainWindow.closeIndicatorDrawer()
//         }
//     }
// }
// }

// expandedComponent: Component {
//     ColumnLayout {
//         spacing: ScreenTools.defaultFontPixelHeight / 2
//
//         SettingsGroupLayout {
//             LabelledButton {
//                 label:      qsTr("通信链接")
//                 buttonText: qsTr("设置")
//
//                 onClicked: {
//                     mainWindow.showSettingsTool(qsTr("通讯链接"))
//                     mainWindow.closeIndicatorDrawer()
//                 }
//             }
//         }
//
//         SettingsGroupLayout {
//             heading:        qsTr("自动连接")
//             visible:        autoConnectSettings.visible
//
//             Repeater {
//                 id: autoConnectRepeater
//
//                 model: [
//                     autoConnectSettings.autoConnectPixhawk,
//                     // autoConnectSettings.autoConnectSiKRadio,
//                     // autoConnectSettings.autoConnectLibrePilot,
//                     autoConnectSettings.autoConnectUDP,
//                     // autoConnectSettings.autoConnectZeroConf,
//                     autoConnectSettings.autoConnectRTKGPS,
//                 ]
//
//                 property var names: [ qsTr("Pixhawk"), qsTr("UDP"), qsTr("RTK") ]
//
//                 FactCheckBoxSlider {
//                     Layout.fillWidth:   true
//                     text:               autoConnectRepeater.names[index]
//                     fact:               modelData
//                     visible:            modelData.visible
//                 }
//             }
//         }
//     }
// }
// }
