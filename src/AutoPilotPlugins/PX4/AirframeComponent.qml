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

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.ScreenTools

SetupPage {
    id:             airframePage
    pageComponent:  (controller && controller.showCustomConfigPanel) ? customFrame : pageComponent

    AirframeComponentController {
        id:         controller
    }

    Component {
        id: customFrame
        Column {
            width:          availableWidth
            spacing:        ScreenTools.defaultFontPixelHeight * 4
            Item {
                width:      1
                height:     1
            }
            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                width:      parent.width * 0.5
                height:     ScreenTools.defaultFontPixelHeight * 4
                wrapMode:   Text.WordWrap
                text:       qsTr("您的设备正在使用自定义的飞控配置. ") +
                            qsTr("此配置只能通过参数编辑器进行修改.\n\n") +
                            qsTr("如果您想重置您的飞控配置并选择一个标准配置, 请点击下方的 '重置' 按钮.")
            }
            QGCButton {
                text:       qsTr("重置")
                enabled:    sys_autostart
                anchors.horizontalCenter: parent.horizontalCenter
                property Fact sys_autostart: controller.getParameterFact(-1, "SYS_AUTOSTART")
                onClicked: {
                    if(sys_autostart) {
                        sys_autostart.value = 0
                    }
                }
            }
        }
    }

    Component {
        id: pageComponent

        Column {
            id:     mainColumn
            width:  availableWidth

            property real _minW:        ScreenTools.defaultFontPixelWidth * 30
            property real _boxWidth:    _minW
            property real _boxSpace:    ScreenTools.defaultFontPixelWidth

            readonly property real spacerHeight: ScreenTools.defaultFontPixelHeight

            onWidthChanged: {
                computeDimensions()
            }

            Component.onCompleted: computeDimensions()

            function computeDimensions() {
                var sw  = 0
                var rw  = 0
                var idx = Math.floor(mainColumn.width / (_minW + ScreenTools.defaultFontPixelWidth))
                if(idx < 1) {
                    _boxWidth = mainColumn.width
                    _boxSpace = 0
                } else {
                    _boxSpace = 0
                    if(idx > 1) {
                        _boxSpace = ScreenTools.defaultFontPixelWidth
                        sw = _boxSpace * (idx - 1)
                    }
                    rw = mainColumn.width - sw
                    _boxWidth = rw / idx
                }
            }

            Item {
                id:             helpApplyRow
                anchors.left:   parent.left
                anchors.right:  parent.right
                height:         Math.max(helpText.contentHeight, applyButton.height)

                QGCLabel {
                    id:             helpText
                    width:          parent.width - applyButton.width - 5
                    text:           (controller.currentVehicleName != "" ?
                                         qsTr("您已连接 %1.").arg(controller.currentVehicleName) :
                                         qsTr("飞控未设置.")) +
                                    qsTr("要更改此配置, 请选择下方的所需飞控然后点击 '应用并重新启动'.")
                    font.bold:      true
                    wrapMode:       Text.WordWrap
                }

                QGCButton {
                    id:             applyButton
                    anchors.right:  parent.right
                    text:           qsTr("应用并重新启动")
                    onClicked:      mainWindow.showMessageDialog(qsTr("Apply and Restart"),
                                                                 qsTr("点击 '应用' 按钮将保存您对飞控配置的更改.<br><br>\
                                                                        所有飞控参数(除了无线电校准)都将被重置.<br><br>\
                                                                        您的设备也将被重新启动, 以便完成进程."),
                                                                 Dialog.Apply | Dialog.Cancel,
                                                                 function() { controller.changeAutostart() })

                }
            }

            Item {
                id:             lastSpacer
                height:         parent.spacerHeight
                width:          10
            }

            Flow {
                id:         flowView
                width:      parent.width
                spacing:    _boxSpace

                ButtonGroup {
                    id: airframeTypeExclusive
                }

                Repeater {
                    model: controller.airframeTypes

                    // Outer summary item rectangle
                    Rectangle {
                        width:  _boxWidth
                        height: ScreenTools.defaultFontPixelHeight * 14
                        color:  qgcPal.window

                        readonly property real titleHeight: ScreenTools.defaultFontPixelHeight * 1.75
                        readonly property real innerMargin: ScreenTools.defaultFontPixelWidth

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                applyButton.primary = true
                                airframeCheckBox.checked = true
                            }
                        }

                        QGCLabel {
                            id:     title
                            text:   modelData.name
                        }

                        Rectangle {
                            anchors.topMargin:  ScreenTools.defaultFontPixelHeight / 2
                            anchors.top:        title.bottom
                            anchors.bottom:     parent.bottom
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            color:              airframeCheckBox.checked ? qgcPal.buttonHighlight : qgcPal.windowShade

                            Image {
                                id:                 image
                                anchors.margins:    innerMargin
                                anchors.top:        parent.top
                                anchors.bottom:     combo.top
                                anchors.left:       parent.left
                                anchors.right:      parent.right
                                fillMode:           Image.PreserveAspectFit
                                smooth:             true
                                mipmap:             true
                                source:             modelData.imageResource
                            }

                            QGCCheckBox {
                                // Although this item is invisible we still use it to manage state
                                id:             airframeCheckBox
                                checked:        modelData.name === controller.currentAirframeType
                                buttonGroup: airframeTypeExclusive
                                visible:        false

                                onCheckedChanged: {
                                    if (checked && combo.currentIndex !== -1) {
                                        console.log("check box change", combo.currentIndex)
                                        controller.autostartId = modelData.airframes[combo.currentIndex].autostartId
                                    }
                                }
                            }

                            QGCComboBox {
                                id:                 combo
                                objectName:         modelData.airframeType + "ComboBox"
                                anchors.margins:    innerMargin
                                anchors.bottom:     parent.bottom
                                anchors.left:       parent.left
                                anchors.right:      parent.right
                                model:              modelData.airframes
                                textRole:           "text"

                                Component.onCompleted: {
                                    if (airframeCheckBox.checked) {
                                        currentIndex = controller.currentVehicleIndex
                                    }
                                }

                                onActivated: (index) => {
                                    applyButton.primary = true
                                    airframeCheckBox.checked = true;
                                    console.log("combo change", index)
                                    controller.autostartId = modelData.airframes[index].autostartId
                                }
                            }
                        }
                    }
                } // Repeater - summary boxes
            } // Flow - summary boxes
        } // Column
    } // Component
} // SetupPage
