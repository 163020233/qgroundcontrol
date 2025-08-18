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

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.ScreenTools
import QGroundControl.Controllers

SetupPage {
    id:             motorPage
    pageComponent:  pageComponent
    enabled:        true

    readonly property int _barHeight:       10
    readonly property int _barWidth:        5
    readonly property int _sliderHeight:    10

    property int neutralValue: 50;
    property int _lastIndex: 0;
    property bool canRunManualTest: controller.vehicle.flightMode !== controller.vehicle.motorDetectionFlightMode && controller.vehicle.armed && motorPage.visible && setupView.visible
    property var shouldRunManualTest: false // Does the operator intend to run the motor test?

    APMSubMotorComponentController {
        id:             controller
    }

    function setMotorDirection(num, reversed) {
        var fact = controller.getParameterFact(-1, "MOT_" + num + "_DIRECTION")
        fact.value = reversed ? -1 : 1;
    }

    Component.onCompleted: controller.vehicle.armed = false

    Component {
        id: pageComponent

        Column {
            spacing: 10

            Row {
                id:         motorSliders
                enabled:    canRunManualTest && shouldRunManualTest
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    Row {
                        id: sliderRow
                        spacing:    ScreenTools.defaultFontPixelWidth * 4

                        Repeater {
                            id:         sliderRepeater
                            model:      controller.vehicle.motorCount == -1 ? 8 : controller.vehicle.motorCount

                            Column {
                                property alias motorSlider: slider
                                spacing:    ScreenTools.defaultFontPixelWidth

                                QGCLabel {
                                    anchors.horizontalCenter:   parent.horizontalCenter
                                    text:                       index + 1
                                }

                                QGCSlider {
                                    id:                         slider
                                    height:                     ScreenTools.defaultFontPixelHeight * _sliderHeight
                                    orientation:                Qt.Vertical
                                    to:               100
                                    value:                      neutralValue

                                    // Give slider 'center sprung' behavior
                                    onPressedChanged: {
                                        if (!slider.pressed) {
                                            slider.value = neutralValue
                                        }
                                        _lastIndex = index
                                    }
                                    // Disable mouse scroll
                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: (wheel) => {
                                            // do nothing
                                            wheel.accepted = true;
                                        }
                                        onPressed: (mouse) => {
                                            // propogate/accept
                                            mouse.accepted = false;
                                        }
                                        onReleased: (mouse) => {
                                            // propogate/accept
                                            mouse.accepted = false;
                                        }
                                    }
                                }
                            } // Column
                        } // Repeater
                    } // Row

                    QGCLabel {
                        width: parent.width
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text:           qsTr("反转电机方向")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                    Rectangle {
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 3
                        width:              parent.width
                        height:             1
                        color:              qgcPal.text
                    }

                    Row {
                        anchors.margins: ScreenTools.defaultFontPixelWidth

                        Repeater {
                            id:         cbRepeater
                            model:      controller.vehicle.motorCount == -1 ? 8 : controller.vehicle.motorCount

                            Column {
                                spacing:    ScreenTools.defaultFontPixelWidth

                                QGCCheckBox {
                                    width: sliderRow.width / (controller.vehicle.motorCount - 0.5)
                                    checked: controller.getParameterFact(-1, "MOT_" + (index + 1) + "_DIRECTION").value == -1
                                    onClicked: {
                                        sliderRepeater.itemAt(index).motorSlider.value = neutralValue
                                        setMotorDirection(index + 1, checked)
                                    }
                                }
                            } // Column
                        } // Repeater
                    } // Row
                } // Column

                // Display the frame currently in use with motor numbers
                APMSubMotorDisplay {
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          height
                    frameType: controller.getParameterFact(-1, "FRAME_CONFIG").value
                }
            } // Row

            QGCLabel {
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("移动滑块将导致电机旋转。请确保电机和螺旋桨没有障碍物！电机旋转方向取决于电机的三个相位如何物理连接到ESC（如果交换了两根导线，旋转方向将翻转）。由于我们无法保证相位的顺序，因此必须在软件中配置电机方向。当滑块向下移动时，螺旋桨应该向进入 housing 的电缆推动空气/水。点击复选框以反转对应螺旋桨的方向。\n\n"
                                     + "Blue Robotics 电机是通过水润滑的，不设计用于在空气中运行。在低速度下，Blue Robotics 电机在空气中运行是可以的，但在短时间内运行。在空气中长时间运行 Blue Robotics 电机可能会导致过热和永久损坏。没有水润滑，Blue Robotics 电机在空气中运行时也可能会发出一些 unpleasant的噪音；这是正常的。")
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                Switch {
                    id: safetySwitch
                    onToggled: {
                        if (controller.vehicle.armed) {
                            shouldRunManualTest = false
                            enabled = false
                            coolDownTimer.start()
                        }

                        controller.vehicle.armed = checked
                        checked = controller.vehicle.armed // Makes the switch stay off if it's not possible to arm
                    }
                }

                // Make sure external changes to Armed are reflected on the switch
                Connections {
                    target: controller.vehicle
                    onArmedChanged:
                    {
                        safetySwitch.checked = armed
                            if (!armed) {
                                shouldRunManualTest = false
                                safetySwitch.enabled = false
                                coolDownTimer.start()
                            } else {
                                shouldRunManualTest = true
                            }
                            for (var sliderIndex=0; sliderIndex<sliderRepeater.count; sliderIndex++) {
                                sliderRepeater.itemAt(sliderIndex).motorSlider.value = neutralValue
                            }
                        }
                }

                QGCLabel {
                    anchors.verticalCenter: safetySwitch.verticalCenter
                    color:  qgcPal.warningText
                    text:   coolDownTimer.running
                                ? qsTr("A 10 second coooldown is required before testing again, please stand by...")
                                : qsTr("Slide this switch to arm the vehicle and enable the motor test (CAUTION!)")
                }
            } // Row

            QGCLabel {
                visible:             controller.vehicle.versionCompare(4, 0, 0) >= 0
                width:               parent.width
                anchors.left:        parent.left
                anchors.right:       parent.right
                font.pointSize:      ScreenTools.largeFontPointSize
                text:                qsTr("自动电机方向检测")
            }

            QGCLabel {
                visible:        controller.vehicle.versionCompare(4, 0, 0) >= 0
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("这将尝试自动检测您的螺旋桨的方向（正常/反转）。\n"
                                   + "请将您的车辆放入水中，点击按钮，等待。请注意，螺旋桨仍然需要连接到正确的输出（螺旋桨 2 和 3 不能交换，例如）。")
            }

            Row {
                visible:    controller.vehicle.versionCompare(4, 0, 0) >= 0
                spacing:    ScreenTools.defaultFontPixelWidth

                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    QGCButton {
                        id: startAutoDetection
                        text: "Auto-Detect Directions"
                        enabled: controller.vehicle.flightMode !== controller.vehicle.motorDetectionFlightMode

                        onClicked: function() {
                            controller.vehicle.flightMode = controller.vehicle.motorDetectionFlightMode
                            controller.vehicle.armed = true
                        }
                    }
                }
                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    Flickable {
                        id: flickable
                        width: 500
                        height: Math.min(contentHeight, 200)
                        contentWidth: width
                        contentHeight: textArea.implicitHeight
                        clip: true

                        TextArea {
                            id: textArea
                            anchors.fill: parent
                            color:  qgcPal.text
                            text: controller.motorDetectionMessages
                            wrapMode: Text.WordWrap
                            background: Rectangle {
                                color: qgcPal.window
                            }
                            onTextChanged: function() {
                                flickable.flick(0, -300)
                            }
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                }
            }

            // Repeats the command signal and updates the checkbox every 50 ms
            Timer {
                id: timer
                interval:       50
                repeat:         true
                running:        canRunManualTest && shouldRunManualTest

                onTriggered: {
                    if (controller.vehicle.armed) {
                            var slider = sliderRepeater.itemAt(_lastIndex)

                            var reversed = controller.getParameterFact(-1, "MOT_" + (_lastIndex + 1) + "_DIRECTION").value == -1

                            if (reversed) {
                                controller.vehicle.motorTest(_lastIndex, 100 - slider.motorSlider.value, 0, false)
                            } else {
                                controller.vehicle.motorTest(_lastIndex, slider.motorSlider.value, 0, false)
                            }
                    }
                }
            }
            Timer {
                id: coolDownTimer
                interval:       11000
                repeat:         false

                onTriggered: {
                    safetySwitch.enabled = true
                }
            }
        } // Column
    } // Component
} // SetupPage
