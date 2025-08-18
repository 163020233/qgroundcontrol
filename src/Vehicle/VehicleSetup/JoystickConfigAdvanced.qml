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
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Controllers
import QGroundControl.FactSystem
import QGroundControl.FactControls

Item {
    width:                  grid.width  + (ScreenTools.defaultFontPixelWidth  * 2)
    height:                 grid.height + (ScreenTools.defaultFontPixelHeight * 2)
    //---------------------------------------------------------------------
    GridLayout {
        id:                 grid
        columns:            2
        columnSpacing:      ScreenTools.defaultFontPixelWidth
        rowSpacing:         ScreenTools.defaultFontPixelHeight
        anchors.centerIn:   parent
        //-------------------------------------------------------------
        //-------------------------------------------------------------
        QGCRadioButton {
            text:               qsTr("全下拨为零油门")
            checked:            _activeJoystick ? _activeJoystick.throttleMode === 1 : false
            onClicked:          _activeJoystick.throttleMode = 1
            Layout.columnSpan:  2
        }
        QGCRadioButton {
            text:               qsTr("中心拨为零油门")
            checked:            _activeJoystick ? _activeJoystick.throttleMode === 0 : false
            onClicked:          _activeJoystick.throttleMode = 0
            Layout.columnSpan:  2
        }
        //-------------------------------------------------------------
        QGCLabel {
            text:               qsTr("弹簧加载油门平滑")
            visible:            _activeJoystick ? _activeJoystick.throttleMode === 0 : false
            Layout.alignment:   Qt.AlignVCenter
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 36
        }
        QGCCheckBox {
            checked:            _activeJoystick ? _activeJoystick.accumulator : false
            visible:            _activeJoystick ? _activeJoystick.throttleMode === 0 : false
            onClicked:          _activeJoystick.accumulator = checked
        }
        //-------------------------------------------------------------
        QGCLabel {
            text:               qsTr("允许负油门")
            visible:            globals.activeVehicle.supportsNegativeThrust
            Layout.alignment:   Qt.AlignVCenter
        }
        QGCCheckBox {
            visible:            globals.activeVehicle.supportsNegativeThrust
            enabled:            globals.activeVehicle.supportsNegativeThrust
            checked:            _activeJoystick ? _activeJoystick.negativeThrust : false
            onClicked:          _activeJoystick.negativeThrust = checked
        }
        //---------------------------------------------------------------------
        QGCLabel {
            text:               qsTr("指数曲线")
        }
        Row {
            spacing:            ScreenTools.defaultFontPixelWidth
            QGCSlider {
                id:             expoSlider
                width:          ScreenTools.defaultFontPixelWidth * 20
                from:   0
                to:   0.75
                Component.onCompleted: value = -_activeJoystick.exponential
                onValueChanged: _activeJoystick.exponential = -value
             }
            QGCLabel {
                id:     expoSliderIndicator
                text:   expoSlider.value.toFixed(2)
            }
        }
        //-----------------------------------------------------------------
        //-- Enable Advanced Mode
        QGCLabel {
            text:               qsTr("启用高级设置（谨慎！）")
            Layout.alignment:   Qt.AlignVCenter
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 36
        }
        QGCCheckBox {
            id:         advancedSettings
            checked:    globals.activeVehicle.joystickMode !== 0
            onClicked: {
                if (!checked) {
                    globals.activeVehicle.joystickMode = 0
                }
            }
        }
        //-----------------------------------------------------------------
        //-- Axis Message Frequency
        QGCLabel {
            text:               qsTr("轴频率 (Hz)：")
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCTextField {
            text:               _activeJoystick.axisFrequencyHz
            enabled:            advancedSettings.checked
            validator:          DoubleValidator { bottom: _activeJoystick.minAxisFrequencyHz; top: _activeJoystick.maxAxisFrequencyHz; }
            inputMethodHints:   Qt.ImhFormattedNumbersOnly
            Layout.alignment:   Qt.AlignVCenter
            onEditingFinished: {
                _activeJoystick.axisFrequencyHz = parseFloat(text)
            }
            visible:            advancedSettings.checked
        }
        //-----------------------------------------------------------------
        //-- Button Repeat Frequency
        QGCLabel {
            text:               qsTr("按钮重复频率 (Hz)：")
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCTextField {
            text:               _activeJoystick.buttonFrequencyHz
            enabled:            advancedSettings.checked
            validator:          DoubleValidator { bottom: _activeJoystick.minButtonFrequencyHz; top: _activeJoystick.maxButtonFrequencyHz; }
            inputMethodHints:   Qt.ImhFormattedNumbersOnly
            Layout.alignment:   Qt.AlignVCenter
            onEditingFinished: {
                _activeJoystick.buttonFrequencyHz = parseFloat(text)
            }
            visible:            advancedSettings.checked
        }
        //-----------------------------------------------------------------
        //-- Enable circle correction
        QGCLabel {
            text:               qsTr("启用圆修正")
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCCheckBox {
            checked:            globals.activeVehicle.joystickMode !== 0
            enabled:            advancedSettings.checked
            Component.onCompleted: {
                checked = _activeJoystick.circleCorrection
            }
            onClicked: {
                _activeJoystick.circleCorrection = checked
            }
            visible:            advancedSettings.checked
        }
        //-----------------------------------------------------------------
        //-- Deadband
        QGCLabel {
            text:               qsTr("死区")
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCCheckBox {
            enabled:            advancedSettings.checked
            checked:            controller.deadbandToggle
            onClicked:          controller.deadbandToggle = checked
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCLabel{
            Layout.fillWidth:   true
            Layout.columnSpan:  2
            font.pointSize:     ScreenTools.smallFontPointSize
            wrapMode:           Text.WordWrap
            visible:            advancedSettings.checked
            text:   qsTr("可以在校准的第一步中通过轻轻摆动每个轴来设置死区。在第一个") +
                    qsTr("校准步骤中，还可以通过单击并垂直拖动相应的轴监视器来调整死区。") 
        }
    }
}


