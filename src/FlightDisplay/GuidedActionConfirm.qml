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
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.UTMSP

Rectangle {
    id:         _root
    width:      ScreenTools.defaultFontPixelWidth * 35
    height:     mainLayout.height + (_margins * 2)
    radius:     ScreenTools.defaultFontPixelWidth / 2
    // color:      qgcPal.window
    color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.6)
    visible:    _utmspEnabled === true ? utmspSliderTrigger: false

    // --------------------------------------------------------
    // 修改：整体下移逻辑】
    // --------------------------------------------------------
    // 1. 确保它水平居中
    anchors.horizontalCenter: parent.horizontalCenter

    // 2. 将它的顶部锁定在父容器顶部
    anchors.top:              parent.top

    // 3. 设置向下偏移的边距
    // 建议数值：toolbar.height(顶栏) + 120(避开图标区)
    // 如果觉得还不够下，就把 120 调大
    anchors.topMargin:        ScreenTools.toolbarHeight + 5
    // --------------------------------------------------------

    z:          QGroundControl.zOrderTopMost

    property var    guidedController
    property var    guidedValueSlider
    property string title                                       // Currently unused
    property alias  message:            messageText.text
    property int    action
    property var    actionData
    property bool   hideTrigger:        false
    property var    mapIndicator
    property alias  optionText:         optionCheckBox.text
    property alias  optionChecked:      optionCheckBox.checked

    property real _margins:         ScreenTools.defaultFontPixelWidth / 2
    property bool _emergencyAction: action === guidedController.actionEmergencyStop

    // Properties of UTM adapter
    property bool   utmspSliderTrigger
    property bool   _utmspEnabled:                       QGroundControl.utmspSupported

    Component.onCompleted: guidedController.confirmDialog = this

    onVisibleChanged: {
        if (visible) {
            slider.focus = true
        }
    }

    onHideTriggerChanged: {
        if (hideTrigger) {
            confirmCancelled()
        }
    }

    function show(immediate) {
        if (immediate) {
            visible = true
        } else {
            // We delay showing the confirmation for a small amount in order for any other state
            // changes to propogate through the system. This way only the final state shows up.
            visibleTimer.restart()
        }
    }

    function confirmCancelled() {
        guidedValueSlider.visible = false
        visible = false
        hideTrigger = false
        visibleTimer.stop()
        if (mapIndicator) {
            mapIndicator.actionCancelled()
            mapIndicator = undefined
        }
    }

    Timer {
        id:             visibleTimer
        interval:       1000
        repeat:         false
        onTriggered:    visible = true
    }

    QGCPalette { id: qgcPal }

    ColumnLayout {
        id:                 mainLayout
        anchors.centerIn:   parent
        width:              parent.width - (_margins * 2)
        spacing:            _margins

        QGCLabel {
            id:                     messageText
            Layout.fillWidth:       true
            horizontalAlignment:    Text.AlignHCenter
            wrapMode:               Text.WordWrap
            font.pointSize:         ScreenTools.defaultFontPointSize
            font.bold:              true
        }

        QGCCheckBox {
            id:                 optionCheckBox
            Layout.alignment:   Qt.AlignHCenter
            text:               ""
            visible:            text !== ""
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCButton {
                id: slider
                text: qsTr("确认执行")

                Layout.fillWidth: true
                enabled: _utmspEnabled === true ? utmspSliderTrigger : true
                // opacity: if(_utmspEnabled){utmspSliderTrigger === true ? 1 : 0.5} else{1}
                // 背景半透明
                background: Rectangle {
                    color: Qt.rgba(qgcPal.button.r, qgcPal.button.g, qgcPal.button.b,
                                   _utmspEnabled ? (utmspSliderTrigger ? 0.8 : 0.4) : 0.8)
                    radius: 8
                }

                onClicked: {
                    _root.visible = false
                    var sliderOutputValue = 0
                    if (guidedValueSlider.visible) {
                        sliderOutputValue = guidedValueSlider.getOutputValue()
                        guidedValueSlider.visible = false
                    }
                    hideTrigger = false
                    guidedController.executeAction(_root.action, _root.actionData, sliderOutputValue, _root.optionChecked)
                    if (mapIndicator) {
                        mapIndicator.actionConfirmed()
                        mapIndicator = undefined
                    }

                    UTMSPStateStorage.indicatorOnMissionStatus = true
                    UTMSPStateStorage.currentNotificationIndex = 7
                    UTMSPStateStorage.currentStateIndex = 3
                }
            }

            // SliderSwitch {
            //     id:                 slider
            //     confirmText:        ScreenTools.isMobile ? qsTr("滑动确认") : qsTr("滑动或按住空格键")
            //     Layout.fillWidth:   true
            //     enabled: _utmspEnabled === true? utmspSliderTrigger : true
            //     opacity: if(_utmspEnabled){utmspSliderTrigger === true ? 1 : 0.5} else{1}

            //     onAccept: {
            //         _root.visible = false
            //         var sliderOutputValue = 0
            //         if (guidedValueSlider.visible) {
            //             sliderOutputValue = guidedValueSlider.getOutputValue()
            //             guidedValueSlider.visible = false
            //         }
            //         hideTrigger = false
            //         guidedController.executeAction(_root.action, _root.actionData, sliderOutputValue, _root.optionChecked)
            //         if (mapIndicator) {
            //             mapIndicator.actionConfirmed()
            //             mapIndicator = undefined
            //         }

            //         UTMSPStateStorage.indicatorOnMissionStatus = true
            //         UTMSPStateStorage.currentNotificationIndex = 7
            //         UTMSPStateStorage.currentStateIndex = 3
            //     }
            // }

            Rectangle {
                height: slider.height * 0.75
                width:  height
                radius: height / 2
                color:  qgcPal.primaryButton

                QGCColoredImage {
                    anchors.margins:    parent.height / 4
                    anchors.fill:       parent
                    source:             "/res/XDelete.svg"
                    fillMode:           Image.PreserveAspectFit
                    color:              qgcPal.text
                }

                QGCMouseArea {
                    fillItem:   parent
                    onClicked:  confirmCancelled()
                }
            }
        }
    }
}

