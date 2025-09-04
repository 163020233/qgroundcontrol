/****************************************************************************
 *
 * (c) 2009-2022 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.FactSystem
import QGroundControl.FactControls

ToolIndicatorPage {
    id:         control
    showExpand: true

    property var    linkConfigs:            QGroundControl.linkManager.linkConfigurations
    property bool   noLinks:                true
    property var    editingConfig:          null
    property var    autoConnectSettings:    QGroundControl.settingsManager.autoConnectSettings

    Component.onCompleted: {
        for (var i = 0; i < linkConfigs.count; i++) {
            var linkConfig = linkConfigs.get(i)
            if (!linkConfig.dynamic && !linkConfig.isAutoConnect) {
                noLinks = false
                break
            }
        }
    }

    contentComponent: Component {
        SettingsGroupLayout {
            heading: qsTr("选择链接")

            QGCLabel {
                text:       qsTr("没有配置的链接")
                visible:    noLinks
            }
            Repeater {
                model: linkConfigs

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // 设备名字显示
                    QGCLabel {
                        text: object.name       // 显示设备名字
                        font.bold: true
                    }

                    // 连接按钮
                    QGCButton {
                        Layout.fillWidth: true
                        visible: !object.dynamic

                        // 根据状态切换按钮文字
                        text: (object.link ? qsTr("断开连接") : qsTr("连接"))

                        // 根据状态切换按钮颜色
                        background: Rectangle {
                            color: object.link ? "#E57373" : "#81C784"   // 红=已连接, 绿=未连接
                            radius: 6
                        }

                        onClicked: {
                            if (object.link) {
                                object.link.disconnect()
                            } else {
                                QGroundControl.linkManager.createConnectedLink(object)
                            }
                            mainWindow.closeIndicatorDrawer()
                        }
                    }
                }
            }

        }

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
    }

    expandedComponent: Component {
        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            SettingsGroupLayout {
                LabelledButton {
                    label:      qsTr("通信链接")
                    buttonText: qsTr("设置")

                    onClicked: {
                        mainWindow.showSettingsTool(qsTr("通讯链接"))
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }

            SettingsGroupLayout {
                heading:        qsTr("自动连接")
                visible:        autoConnectSettings.visible

                Repeater {
                    id: autoConnectRepeater

                    model: [
                        autoConnectSettings.autoConnectPixhawk,
                        // autoConnectSettings.autoConnectSiKRadio,
                        // autoConnectSettings.autoConnectLibrePilot,
                        autoConnectSettings.autoConnectUDP,
                        // autoConnectSettings.autoConnectZeroConf,
                        autoConnectSettings.autoConnectRTKGPS,
                    ]

                    property var names: [ qsTr("Pixhawk"), qsTr("UDP"), qsTr("RTK") ]
      
                    FactCheckBoxSlider {
                        Layout.fillWidth:   true
                        text:               autoConnectRepeater.names[index]
                        fact:               modelData
                        visible:            modelData.visible
                    }
                }
            }
        }
    }
}
