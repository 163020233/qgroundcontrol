import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette

// Camera section for mission item editors
Column {
    anchors.left:   parent.left
    anchors.right:  parent.right
    spacing:        _margin

    property alias buttonGroup:  cameraSectionHeader.buttonGroup
    property alias showSpacer:      cameraSectionHeader.showSpacer
    property alias checked:         cameraSectionHeader.checked

    property var    _camera:        missionItem.cameraSection
    property real   _fieldWidth:    ScreenTools.defaultFontPixelWidth * 16
    property real   _margin:        ScreenTools.defaultFontPixelWidth / 2

    SectionHeader {
        id:             cameraSectionHeader
        anchors.left:   parent.left
        anchors.right:  parent.right
        text:           qsTr("相机")
        checked:        false
    }

    Column {
        anchors.left:   parent.left
        anchors.right:  parent.right
        spacing:        _margin
        visible:        cameraSectionHeader.checked

        FactComboBox {
            id:             cameraActionCombo
            anchors.left:   parent.left
            anchors.right:  parent.right
            fact:           _camera.cameraAction
            indexModel:     false
        }

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelWidth
            visible:        _camera.cameraAction.rawValue === 1

            QGCLabel {
                text:               qsTr("时间")
                Layout.fillWidth:   true
            }
            FactTextField {
                fact:                   _camera.cameraPhotoIntervalTime
                Layout.preferredWidth:  _fieldWidth
            }
        }

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelWidth
            visible:        _camera.cameraAction.rawValue === 2

            QGCLabel {
                text:               qsTr("距离")
                Layout.fillWidth:   true
            }
            FactTextField {
                fact:                   _camera.cameraPhotoIntervalDistance
                Layout.preferredWidth:  _fieldWidth
            }
        }

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelWidth
            visible:        _camera.cameraModeSupported

            QGCCheckBox {
                id:                 modeCheckBox
                text:               qsTr("模式")
                checked:            _camera.specifyCameraMode
                onClicked:          _camera.specifyCameraMode = checked
            }
            FactComboBox {
                fact:               _camera.cameraMode
                indexModel:         false
                enabled:            modeCheckBox.checked
                Layout.fillWidth:   true
            }
        }

        GridLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            columnSpacing:  ScreenTools.defaultFontPixelWidth / 2
            rowSpacing:     0
            columns:        3

            QGCLabel { text: qsTr("云台") }
            QGCLabel { text: qsTr("俯仰") }
            QGCLabel { text: qsTr("偏航") }

            QGCCheckBox {
                id:                 gimbalCheckBox
                checked:            _camera.specifyGimbal
                onClicked:          _camera.specifyGimbal = checked
                Layout.fillWidth:   true
            }
            FactTextField {
                fact:           _camera.gimbalPitch
                implicitWidth:  ScreenTools.defaultFontPixelWidth * 9
                enabled:        gimbalCheckBox.checked
            }

            FactTextField {
                fact:           _camera.gimbalYaw
                implicitWidth:  ScreenTools.defaultFontPixelWidth * 9
                enabled:        gimbalCheckBox.checked
            }
        }
    }
}
