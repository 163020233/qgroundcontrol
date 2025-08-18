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
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.ScreenTools
import QGroundControl.Controllers

QGCPopupDialog {
    id:         root
    title:      qsTr("编辑位置")
    buttons:    Dialog.Close

    property alias coordinate:                  controller.coordinate
    property bool  showSetPositionFromVehicle:  true

    property real _margin:          ScreenTools.defaultFontPixelWidth / 2
    property real _textFieldWidth:  ScreenTools.defaultFontPixelWidth * 20
    property bool _showGeographic:  coordinateSystemCombo.comboBox.currentIndex === 0
    property bool _showUTM:         coordinateSystemCombo.comboBox.currentIndex === 1
    property bool _showMGRS:        coordinateSystemCombo.comboBox.currentIndex === 2
    property bool _showVehicle:     coordinateSystemCombo.comboBox.currentIndex === 3

    EditPositionDialogController {
        id: controller

        Component.onCompleted: initValues()
    }

    ColumnLayout {
        spacing: _margin

        LabelledComboBox {
            id:                 coordinateSystemCombo
            Layout.fillWidth:   true
            label:              qsTr("坐标系统")
            model:              showSetPositionFromVehicle && globals.activeVehicle ? 
                                    [ qsTr("地理"), qsTr("通用横轴墨卡托投影"), qsTr("军事网格参考"), qsTr("设备位置") ] :
                                    [ qsTr("地理"), qsTr("通用横轴墨卡托投影"), qsTr("军事网格参考") ]
        }

        LabelledFactTextField {
            label:              qsTr("纬度")
            fact:               controller.latitude
            textFieldPreferredWidth: _textFieldWidth
            Layout.fillWidth:   true
            visible:            _showGeographic
        }

        LabelledFactTextField {
            label:              qsTr("经度")
            fact:               controller.longitude
            textFieldPreferredWidth: _textFieldWidth
            Layout.fillWidth:   true
            visible:            _showGeographic
        }

        LabelledButton {
            label:               qsTr("设置位置")
            buttonText:          qsTr("移动")
            visible:             _showGeographic
            onClicked: {
                controller.setFromGeo()
                root.close()
            }
        }

        LabelledFactTextField {
            label:              qsTr("区域")
            fact:               controller.zone
            textFieldPreferredWidth: _textFieldWidth
            Layout.fillWidth:   true
            visible:            _showUTM
        }

        LabelledFactComboBox {
            label:              qsTr("半球")
            fact:               controller.hemisphere
            indexModel:         false
            Layout.fillWidth:   true
            visible:            _showUTM
        }

        LabelledFactTextField {
            label:              qsTr("东")
            fact:               controller.easting
            textFieldPreferredWidth: _textFieldWidth
            Layout.fillWidth:   true
            visible:            _showUTM
        }

        LabelledFactTextField {
            label:              qsTr("北")
            fact:               controller.northing
            textFieldPreferredWidth: _textFieldWidth
            Layout.fillWidth:   true
            visible:            _showUTM
        }

        LabelledButton {
            label:               qsTr("设置位置")
            buttonText:          qsTr("移动")
            visible:             _showUTM
            onClicked: {
                controller.setFromUTM()
                root.close()
            }
        }

        LabelledFactTextField {
            label:              qsTr("MGRS")
            fact:               controller.mgrs
            visible:            _showMGRS
            textFieldPreferredWidth: _textFieldWidth
            Layout.fillWidth:   true
        }

        LabelledButton {
            label:               qsTr("设置位置")
            buttonText:          qsTr("移动")
            visible:             _showMGRS
            onClicked: {
                controller.setFromMGRS()
                root.close()
            }
        }

        LabelledButton {
            label:               qsTr("设置位置")
            buttonText:          qsTr("移动")
            visible:             _showVehicle
            onClicked: {
                controller.setFromVehicle()
                root.close()
            }
        }
    }
}
