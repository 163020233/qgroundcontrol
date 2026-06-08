/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * GuidedActionConfirm.qml — 安卓风格确认面板
 * 整体背景透明，圆角卡片 + 滑动确认
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

Item {
    id:         _root
    width:      ScreenTools.defaultFontPixelWidth * 35
    height:     mainLayout.height + (_margins * 2)
    visible:    _utmspEnabled === true ? utmspSliderTrigger: false

    anchors.left: parent.left
    anchors.leftMargin: 70
    anchors.top: parent.top
    anchors.topMargin:  _toolsMargin + parentToolInsets.topEdgeLeftInset
    z:          QGroundControl.zOrderTopMost

    property var    guidedController
    property var    guidedValueSlider
    property string title
    property alias  message:            messageText.text
    property int    action
    property var    actionData
    property bool   hideTrigger:        false
    property var    mapIndicator
    property alias  optionText:         optionCheckBox.text
    property alias  optionChecked:      optionCheckBox.checked

    property real _margins:         ScreenTools.defaultFontPixelWidth / 2
    property bool _emergencyAction: action === guidedController.actionEmergencyStop

    property bool   utmspSliderTrigger
    property bool   _utmspEnabled:  QGroundControl.utmspSupported

    Component.onCompleted: guidedController.confirmDialog = this

    onVisibleChanged: {
        if (visible) slider.focus = true
    }

    onHideTriggerChanged: {
        if (hideTrigger) confirmCancelled()
    }

    function show(immediate) {
        if (immediate) {
            visible = true
        } else {
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

    // 背景半透明遮罩（整个屏幕）
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: -parent.topMargin - 500
        anchors.leftMargin: -parent.leftMargin - 500
        anchors.rightMargin: -500
        anchors.bottomMargin: -500
        color: Qt.rgba(0, 0, 0, 0.5)
        z: -1
    }

    // 确认卡片
    Rectangle {
        id:                     _card
        anchors.centerIn:       parent
        width:                  parent.width
        height:                 parent.height
        radius:                 ScreenTools.defaultFontPixelWidth * 0.8
        color:                  Qt.rgba(0.1, 0.1, 0.1, 0.85)
        border.color:           Qt.rgba(1, 1, 1, 0.1)
        border.width:           1

        ColumnLayout {
            id:                 mainLayout
            anchors.centerIn:   parent
            width:              parent.width - (_margins * 2)
            spacing:            _margins

            // 标题/提示文字
            QGCLabel {
                id:                     messageText
                Layout.fillWidth:       true
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.defaultFontPointSize
                font.bold:              true
                color:                  "white"
            }

            // 复选框
            QGCCheckBox {
                id:                 optionCheckBox
                Layout.alignment:   Qt.AlignHCenter
                text:               ""
                visible:            text !== ""
            }

            // 滑动确认 + 取消
            RowLayout {
                Layout.fillWidth:   true
                spacing:            ScreenTools.defaultFontPixelWidth

                // 滑动确认
                SliderSwitch {
                    id:                 slider
                    confirmText:        ScreenTools.isMobile ? qsTr("滑动确认") : qsTr("滑动")
                    Layout.fillWidth:   true
                    enabled:            _utmspEnabled === true ? utmspSliderTrigger : true
                    opacity:            if(_utmspEnabled) { utmspSliderTrigger === true ? 1 : 0.5 } else { 1 }

                    onAccept: {
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

                // 取消按钮
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
                        color:              "white"
                    }

                    QGCMouseArea {
                        fillItem:   parent
                        onClicked:  confirmCancelled()
                    }
                }
            }
        }
    }
}
