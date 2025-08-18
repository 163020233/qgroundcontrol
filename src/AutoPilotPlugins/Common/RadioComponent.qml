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
import QGroundControl.Palette

SetupPage {
    id:             radioPage
    pageComponent:  pageComponent

    Component {
        id: pageComponent

        Item {
            width:  availableWidth
            height: Math.max(leftColumn.height, rightColumn.height)

            function setupPageCompleted() {
                controller.start()
                updateChannelCount()
            }

            function updateChannelCount()
            {
            }

            QGCPalette { id: qgcPal; colorGroupEnabled: radioPage.enabled }

            RadioComponentController {
                id:             controller
                statusText:     statusText
                cancelButton:   cancelButton
                nextButton:     nextButton
                skipButton:     skipButton
                onChannelCountChanged:              updateChannelCount()
                onFunctionMappingChangedAPMReboot:  mainWindow.showMessageDialog(qsTr("重启 required"), qsTr("您的摇杆映射已更改，您必须重新启动车辆才能正确操作。"))
                onThrottleReversedCalFailure:       mainWindow.showMessageDialog(qsTr("油门通道反转"), qsTr("校准失败。您的 transmitter 上的油门通道已反转。您必须在 transmitter 上更正此设置，才能完成校准。"))
            }

            Component {
                id: spektrumBindDialogComponent

                QGCPopupDialog {
                    title:      qsTr("绑定 Spektrum 接收机")
                    buttons:    Dialog.Ok | Dialog.Cancel

                    onAccepted: { controller.spektrumBindMode(radioGroup.checkedButton.bindMode) }

                    ButtonGroup { id: radioGroup }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight / 2

                        QGCLabel {
                            wrapMode:   Text.WordWrap
                            text:       qsTr("点击 OK 将您的 Spektrum 接收机放入绑定模式。")
                        }

                        QGCLabel {
                            wrapMode:   Text.WordWrap
                            text:       qsTr("选择下面的具体接收机类型：")
                        }

                        QGCRadioButton {
                            text:               qsTr("DSM2 模式")
                            ButtonGroup.group:  radioGroup
                            property int bindMode: RadioComponentController.DSM2
                        }

                        QGCRadioButton {
                            text:               qsTr("DSMX (7 个通道或更少)")
                            ButtonGroup.group:  radioGroup
                            property int bindMode: RadioComponentController.DSMX7
                        }

                        QGCRadioButton {
                            checked:            true
                            text:               qsTr("DSMX (8 个通道或更多)")
                            ButtonGroup.group:  radioGroup
                            property int bindMode: RadioComponentController.DSMX8
                        }
                    }
                }
            }

            // Live channel monitor control component
            Component {
                id: channelMonitorDisplayComponent

                Item {
                    property int    rcValue:    1500


                    property int            __lastRcValue:      1500
                    readonly property int   __rcValueMaxJitter: 2
                    property color          __barColor:         qgcPal.windowShade

                    readonly property int _pwmMin:      800
                    readonly property int _pwmMax:      2200
                    readonly property int _pwmRange:    _pwmMax - _pwmMin

                    // Bar
                    Rectangle {
                        id:                     bar
                        anchors.verticalCenter: parent.verticalCenter
                        width:                  parent.width
                        height:                 parent.height / 2
                        color:                  __barColor
                    }

                    // Center point
                    Rectangle {
                        anchors.horizontalCenter:   parent.horizontalCenter
                        width:                      globals.defaultTextWidth / 2
                        height:                     parent.height
                        color:                      qgcPal.window
                    }

                    // Indicator
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:                  parent.height * 0.75
                        height:                 width
                        radius:                 width / 2
                        color:                  qgcPal.text
                        visible:                mapped
                        x:                      (((reversed ? _pwmMax - rcValue : rcValue - _pwmMin) / _pwmRange) * parent.width) - (width / 2)
                    }

                    QGCLabel {
                        anchors.fill:           parent
                        horizontalAlignment:    Text.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        text:                   qsTr("未映射")
                        visible:                !mapped
                    }

                    ColorAnimation {
                        id:         barAnimation
                        target:     bar
                        property:   "color"
                        from:       "yellow"
                        to:         __barColor
                        duration:   1500
                    }
                }
            } // Component - channelMonitorDisplayComponent

            // Left side column
            Column {
                id:             leftColumn
                anchors.left:   parent.left
                anchors.right:  columnSpacer.left
                spacing:        10

                // Attitude Controls
                Column {
                    width:      parent.width
                    spacing:    5
                    QGCLabel { text: qsTr("姿态控制") }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2
                        QGCLabel {
                            id:     rollLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("横滚")
                        }

                        Loader {
                            id:                 rollLoader
                            anchors.left:       rollLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.rollChannelMapped
                            property bool reversed:         controller.rollChannelReversed
                        }

                        Connections {
                            target: controller

                            onRollChannelRCValueChanged: (rcValue) => rollLoader.item.rcValue = rcValue
                        }
                    }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2

                        QGCLabel {
                            id:     pitchLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("俯仰")
                        }

                        Loader {
                            id:                 pitchLoader
                            anchors.left:       pitchLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.pitchChannelMapped
                            property bool reversed:         controller.pitchChannelReversed
                        }

                        Connections {
                            target: controller

                            onPitchChannelRCValueChanged: (rcValue) => pitchLoader.item.rcValue = rcValue
                        }
                    }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2

                        QGCLabel {
                            id:     yawLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("偏航")
                        }

                        Loader {
                            id:                 yawLoader
                            anchors.left:       yawLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.yawChannelMapped
                            property bool reversed:         controller.yawChannelReversed
                        }

                        Connections {
                            target: controller

                            onYawChannelRCValueChanged: (rcValue) => yawLoader.item.rcValue = rcValue
                        }
                    }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2

                        QGCLabel {
                            id:     throttleLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("油门")
                        }

                        Loader {
                            id:                 throttleLoader
                            anchors.left:       throttleLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.throttleChannelMapped
                            property bool reversed:         controller.throttleChannelReversed
                        }

                        Connections {
                            target:                             controller
                            onThrottleChannelRCValueChanged:    (rcValue) => throttleLoader.item.rcValue = rcValue
                        }
                    }
                } // Column - Attitude Control labels

                // Command Buttons
                Row {
                    spacing: 10

                    QGCButton {
                        id:         skipButton
                        text:       qsTr("跳过")
                        onClicked:  controller.skipButtonClicked()
                    }

                    QGCButton {
                        id:         cancelButton
                        text:       qsTr("取消")
                        onClicked:  controller.cancelButtonClicked()
                    }

                    QGCButton {
                        id:         nextButton
                        primary:    true
                        text:       qsTr("校准")

                        onClicked: {
                            if (text === qsTr("校准")) {
                                if (controller.channelCount < controller.minChannelCount) {
                                    mainWindow.showMessageDialog(qsTr("无线电未准备好"),
                                                                 controller.channelCount == 0 ? qsTr("请先打开 transmitter.") :
                                                                                                (controller.channelCount < controller.minChannelCount ?
                                                                                                     qsTr("%1 个通道或更多是飞行所需.").arg(controller.minChannelCount) :
                                                                                                     qsTr("准备校准.")))
                                } else {
                                    mainWindow.showMessageDialog(qsTr("零偏"),
                                                                 qsTr("校准前请先将所有偏置调整到零. 点击确定开始校准.\n\n%1").arg(
                                                                     (QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ? "" : qsTr("请确保所有电机功率已断开并从车辆中移除所有 props."))),
                                                                 Dialog.Ok,
                                                                 function() { controller.nextButtonClicked() })
                                }
                            } else {
                                controller.nextButtonClicked()
                            }
                        }
                    }
                } // Row - Buttons

                // Status Text
                QGCLabel {
                    id:         statusText
                    width:      parent.width
                    wrapMode:   Text.WordWrap
                }

                Rectangle {
                    width:          parent.width
                    height:         1
                    border.color:   qgcPal.text
                    border.width:   1
                }

                QGCLabel { text: qsTr("额外无线电设置:") }

                ColumnLayout {
                    id:                 switchSettingsGrid
                    anchors.left:       parent.left
                    anchors.right:      parent.right

                    Repeater {
                        model: QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ?
                                   (QGroundControl.multiVehicleManager.activeVehicle.multiRotor ?
                                        [ "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3"] :
                                        [ "RC_MAP_FLAPS", "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3"]) :
                                   0

                        LabelledFactComboBox {
                            label:               fact.shortDescription
                            fact:                controller.getParameterFact(-1, modelData)
                            indexModel:          false
                        }
                    }
                }

                RowLayout {
                    QGCButton {
                        id:         bindButton
                        text:       qsTr("绑定")
                        onClicked:  spektrumBindDialogComponent.createObject(mainWindow).open()
                    }

                    QGCButton {
                        text:       qsTr("CRSF 绑定")
                        onClicked:  mainWindow.showMessageDialog(qsTr("CRSF 绑定"),
                                                                 qsTr("将 CRSF 接收器置于绑定模式. 点击确定."),
                                                                 Dialog.Ok | Dialog.Cancel,
                                                                 function() { controller.crsfBindMode() })
                    }

                    QGCButton {
                        text:       qsTr("复制偏置")
                        onClicked:  mainWindow.showMessageDialog(qsTr("复制偏置"),
                                                                 qsTr("将摇杆居中并将油门拉到底, 然后点击确定复制偏置. 复制完成后, 请将无线电偏置调整回零."),
                                                                 Dialog.Ok | Dialog.Cancel,
                                                                 function() { controller.copyTrims() })
                    }
                }
            } // Column - Left Column

            Item {
                id:             columnSpacer
                anchors.right:  rightColumn.left
                width:          20
            }

            // Right side column
            Column {
                id:             rightColumn
                anchors.top:    parent.top
                anchors.right:  parent.right
                width:          ScreenTools.defaultFontPixelWidth * 40
                spacing:        ScreenTools.defaultFontPixelHeight / 2

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCRadioButton {
                        text:       qsTr("模式 1")
                        checked:    controller.transmitterMode == 1
                        onClicked:  controller.transmitterMode = 1
                    }

                    QGCRadioButton {
                        text:       qsTr("模式 2")
                        checked:    controller.transmitterMode == 2
                        onClicked:  controller.transmitterMode = 2
                    }
                }

                Image {
                    width:      parent.width
                    fillMode:   Image.PreserveAspectFit
                    smooth:     true
                    source:     controller.imageHelp
                }

                RCChannelMonitor {
                    width:      parent.width
                    twoColumn:  true
                }
            } // Column - Right Column
        } // Item
    } // Component - pageComponent
} // SetupPage
