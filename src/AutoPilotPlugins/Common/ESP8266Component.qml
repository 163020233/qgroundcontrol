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
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Controllers

Item {

    property real _margins:         ScreenTools.defaultFontPixelHeight
    property real _middleRowWidth:  ScreenTools.defaultFontPixelWidth * 18
    property real _editFieldWidth:  ScreenTools.defaultFontPixelWidth * 16
    property real _labelWidth:      ScreenTools.defaultFontPixelWidth * 10
    property real _statusWidth:     ScreenTools.defaultFontPixelWidth * 6
    property real _smallFont:       ScreenTools.smallFontPointSize

    readonly property string    dialogTitle:    qsTr("控制器 WiFi 桥接")
    property int                stStatus:       XMLHttpRequest.UNSENT
    property int                stErrorCount:   0
    property bool               stResetCounters:false

    ESP8266ComponentController {
        id: controller
    }

    Timer {
        id: timer
    }

    function thisThingHasNoNumberLocaleSupport(n) {
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",").replace(",,", ",")
    }

    function updateStatus() {
        timer.stop()
        var req = new XMLHttpRequest;
        var url = "http://"
        url += controller.wifiIPAddress
        url += "/status.json"
        if(stResetCounters) {
            url = url + "?r=1"
            stResetCounters = false
        }
        req.open("GET", url);
        req.onreadystatechange = function() {
            stStatus = req.readyState;
            if (stStatus === XMLHttpRequest.DONE) {
                var objectArray = JSON.parse(req.responseText);
                if (objectArray.errors !== undefined) {
                    console.log(qsTr("获取 WiFi 桥接状态错误: %1").arg(objectArray.errors[0].message))
                    stErrorCount = stErrorCount + 1
                    if(stErrorCount < 2)
                        timer.start()
                } else {
                    //-- This should work but it doesn't
                    //   var n = 34523453.345
                    //   n.toLocaleString()
                    //   "34,523,453.345"
                    vpackets.text   = thisThingHasNoNumberLocaleSupport(objectArray["vpackets"])
                    vsent.text      = thisThingHasNoNumberLocaleSupport(objectArray["vsent"])
                    vlost.text      = thisThingHasNoNumberLocaleSupport(objectArray["vlost"])
                    gpackets.text   = thisThingHasNoNumberLocaleSupport(objectArray["gpackets"])
                    gsent.text      = thisThingHasNoNumberLocaleSupport(objectArray["gsent"])
                    glost.text      = thisThingHasNoNumberLocaleSupport(objectArray["glost"])
                    stErrorCount    = 0
                    timer.start()
                }
            }
        }
        req.send()
    }

    Component.onCompleted: {
        timer.interval = 1000
        timer.repeat = true
        timer.triggered.connect(updateStatus)
        timer.start()
    }

    property Fact wifiMode:     controller.getParameterFact(controller.componentID, "WIFI_MODE",      false) //-- Don't bitch about missing as this is new
    property Fact wifiChannel:  controller.getParameterFact(controller.componentID, "WIFI_CHANNEL")
    property Fact hostPort:     controller.getParameterFact(controller.componentID, "WIFI_UDP_HPORT")
    property Fact clientPort:   controller.getParameterFact(controller.componentID, "WIFI_UDP_CPORT")

    Item {
        id:             panel
        anchors.fill:   parent

        Flickable {
            clip:                                       true
            anchors.fill:                               parent
            contentHeight:                              mainCol.height
            flickableDirection:                         Flickable.VerticalFlick
            Column {
                id:                                     mainCol
                spacing:                                _margins
                anchors.horizontalCenter:               parent.horizontalCenter
                Item { width: 1; height: _margins * 0.5; }
                QGCLabel {
                    text:                               qsTr("ESP 控制器 WiFi 桥接设置")
                    font.bold:                          true
                }
                Rectangle {
                    color:                              qgcPal.windowShade
                    width:                              statusLayout.width  + _margins * 4
                    height:                             settingsRow.height  + _margins * 2
                    Row {
                        id:                             settingsRow
                        spacing:                        _margins * 4
                        anchors.centerIn:               parent
                        QGCColoredImage {
                            color:                      qgcPal.text
                            width:                      ScreenTools.defaultFontPixelWidth * 12
                            height:                     width * 1.45
                            sourceSize.height:          width * 1.45
                            mipmap:                     true
                            fillMode:                   Image.PreserveAspectFit
                            source:                     wifiMode ? (wifiMode.value === 0 ? "/qmlimages/APMode.svg" : "/qmlimages/StationMode.svg") : "/qmlimages/APMode.svg"
                            anchors.verticalCenter:     parent.verticalCenter
                        }
                        Column {
                            spacing:                        _margins * 0.5
                            anchors.verticalCenter:         parent.verticalCenter
                            Row {
                                visible:                    wifiMode
                                QGCLabel {
                                    text:                   qsTr("WiFi 模式")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       modeField.baseline
                                }
                                QGCComboBox {
                                    id:                     modeField
                                    width:                  _editFieldWidth
                                    model:                  ["Access Point Mode", "Station Mode"]
                                    currentIndex:           wifiMode ? wifiMode.value : 0
                                    onActivated: (index) => {
                                        wifiMode.value = index
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("WiFi 通道")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       channelField.baseline
                                }
                                QGCComboBox {
                                    id:                     channelField
                                    width:                  _editFieldWidth
                                    enabled:                wifiMode ? wifiMode.value === 0 : true
                                    model:                  controller.wifiChannels
                                    currentIndex:           wifiChannel ? wifiChannel.value - 1 : 0
                                    onActivated: (index) => {
                                        wifiChannel.value = index + 1
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("WiFi 访问点 SSID")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       ssidField.baseline
                                }
                                QGCTextField {
                                    id:                     ssidField
                                    width:                  _editFieldWidth
                                    text:                   controller.wifiSSID
                                    maximumLength:          16
                                    onEditingFinished: {
                                        controller.wifiSSID = text
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("WiFi 访问点密码")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       passwordField.baseline
                                }
                                QGCTextField {
                                    id:                     passwordField
                                    width:                  _editFieldWidth
                                    text:                   controller.wifiPassword
                                    maximumLength:          16
                                    onEditingFinished: {
                                        controller.wifiPassword = text
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("WiFi 客户端 SSID")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       stassidField.baseline
                                }
                                QGCTextField {
                                    id:                     stassidField
                                    width:                  _editFieldWidth
                                    text:                   controller.wifiSSIDSta
                                    maximumLength:          16
                                    enabled:                wifiMode && wifiMode.value === 1
                                    onEditingFinished: {
                                        controller.wifiSSIDSta = text
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("WiFi 客户端密码")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       passwordStaField.baseline
                                }
                                QGCTextField {
                                    id:                     passwordStaField
                                    width:                  _editFieldWidth
                                    text:                   controller.wifiPasswordSta
                                    maximumLength:          16
                                    enabled:                wifiMode && wifiMode.value === 1
                                    onEditingFinished: {
                                        controller.wifiPasswordSta = text
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("UART 波特率")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       baudField.baseline
                                }
                                QGCComboBox {
                                    id:                     baudField
                                    width:                  _editFieldWidth
                                    model:                  controller.baudRates
                                    currentIndex:           controller.baudIndex
                                    onActivated: (index) => {
                                        controller.baudIndex = index
                                    }
                                }
                            }
                            Row {
                                QGCLabel {
                                    text:                   qsTr("QGC UDP 端口")
                                    width:                  _middleRowWidth
                                    anchors.baseline:       qgcportField.baseline
                                }
                                QGCTextField {
                                    id:                     qgcportField
                                    width:                  _editFieldWidth
                                    text:                   hostPort ? hostPort.valueString : ""
                                    validator:              IntValidator {bottom: 1024; top: 65535;}
                                    inputMethodHints:       Qt.ImhDigitsOnly
                                    onEditingFinished: {
                                        hostPort.value = text
                                    }
                                }
                            }
                        }
                    }
                }
                QGCLabel {
                    text:                               qsTr("ESP WiFi桥接状态")
                    font.bold:                          true
                }
                Rectangle {
                    color:                              qgcPal.windowShade
                    width:                              statusLayout.width  + _margins * 4
                    height:                             statusLayout.height + _margins * 2
                    GridLayout {
                       id:                              statusLayout
                       columns:                         3
                       columnSpacing:                   _margins * 2
                       anchors.centerIn:                parent
                       QGCLabel {
                           text:                        qsTr("桥接/设备连接")
                           Layout.alignment:            Qt.AlignHCenter
                       }
                       QGCLabel {
                           text:                        qsTr("桥接/QGC 连接")
                           Layout.alignment:            Qt.AlignHCenter
                       }
                       QGCLabel {
                           text:                        qsTr("QGC/桥接")
                           Layout.alignment:            Qt.AlignHCenter
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息接收")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               id:                      vpackets
                               font.pointSize:          _smallFont
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               font.pointSize:          _smallFont
                               text:                    qsTr("消息接收")
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               id:                      gpackets
                               font.pointSize:          _smallFont
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               font.pointSize:          _smallFont
                               text:                    qsTr("消息接收")
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               font.pointSize:          _smallFont
                               text:                    controller.vehicle ? thisThingHasNoNumberLocaleSupport(controller.vehicle.messagesReceived) : 0
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息丢失")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               id:                      vlost
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                               font.pointSize:          _smallFont
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息丢失")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               id:                      glost
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                               font.pointSize:          _smallFont
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息丢失")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               text:                    controller.vehicle ? thisThingHasNoNumberLocaleSupport(controller.vehicle.messagesLost) : 0
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                               font.pointSize:          _smallFont
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息发送")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               id:                      vsent
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                               font.pointSize:          _smallFont
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息发送")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               id:                      gsent
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                               font.pointSize:          _smallFont
                           }
                       }
                       Row {
                           spacing:                     _margins
                           QGCLabel {
                               text:                    qsTr("消息发送")
                               font.pointSize:          _smallFont
                               width:                   _labelWidth
                           }
                           QGCLabel {
                               text:                    controller.vehicle ? thisThingHasNoNumberLocaleSupport(controller.vehicle.messagesSent) : 0
                               width:                   _statusWidth
                               horizontalAlignment:     Text.AlignRight
                               font.pointSize:          _smallFont
                           }
                       }
                    }
                }
                Row {
                    spacing:                            _margins
                    anchors.horizontalCenter:           parent.horizontalCenter
                    QGCButton {
                        text:                           qsTr("恢复默认值")
                        width:                          _editFieldWidth
                        onClicked: {
                            controller.restoreDefaults()
                        }
                    }
                    QGCButton {
                        text:                           qsTr("重启WiFi桥接")
                        enabled:                        !controller.busy
                        width:                          _editFieldWidth
                        onClicked: {
                            rebootDialog.visible = true
                        }
                        MessageDialog {
                            id:         rebootDialog
                            visible:    false
                            buttons:    MessageDialog.Yes | MessageDialog.No
                            title:      qsTr("重启WiFi桥接")
                            text:       qsTr("这将重启WiFi桥接，使您所做的更改生效。请注意，您可能需要更改计算机的WiFi设置和QGroundControl链接设置以匹配这些更改。您确定要重启它吗？")
                            onButtonClicked: function (button, role) {
                                switch (button) {
                                case MessageDialog.Yes:
                                    controller.reboot()
                                    rebootDialog.visible = false
                                    break;
                                case MessageDialog.No:
                                    rebootDialog.visible = false
                                    break;
                                }
                            }
                        }
                    }
                    QGCButton {
                        text:                           qsTr("重置计数")
                        width:                          _editFieldWidth
                        onClicked: {
                            stResetCounters = true;
                            updateStatus()
                            if(controller.vehicle)
                                controller.vehicle.resetCounters()
                        }
                    }
                }
            }
        }
    }
}
