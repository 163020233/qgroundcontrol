/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.ScreenTools
import QGroundControl.SettingsManager
import QGroundControl.Controls

FirstRunPrompt {
    title:      qsTr("测量单位")
    promptId:   QGroundControl.corePlugin.unitsFirstRunPromptId

    property real   _margins:           ScreenTools.defaultFontPixelHeight / 2
    property var    _unitsSettings:     QGroundControl.settingsManager.unitsSettings
    property var    _rgFacts:           [ _unitsSettings.horizontalDistanceUnits, _unitsSettings.verticalDistanceUnits, _unitsSettings.areaUnits, _unitsSettings.speedUnits, _unitsSettings.temperatureUnits ]
    property var    _rgLabels:          [ qsTr("水平距离"), qsTr("垂直距离"), qsTr("面积"), qsTr("速度"), qsTr("温度") ]
    property int    _cVisibleFacts:     0

    Component.onCompleted: {
        var cVisibleFacts = 0
        for (var i=0; i<_rgFacts.length; i++) {
            if (_rgFacts[i].visible) {
                cVisibleFacts++
            }
        }
        _cVisibleFacts = cVisibleFacts
    }

    function changeSystemOfUnits(metric) {
        // Hack to force reload the ComboBoxes, otherwise they don't update
        unitComboBoxRepeater.model = 0
        unitComboBoxRepeater.model = _rgFacts.length

        if (_unitsSettings.horizontalDistanceUnits.visible) {
            _unitsSettings.horizontalDistanceUnits.value = metric ? UnitsSettings.HorizontalDistanceUnitsMeters : UnitsSettings.HorizontalDistanceUnitsFeet
        }
        if (_unitsSettings.verticalDistanceUnits.visible) {
            _unitsSettings.verticalDistanceUnits.value = metric ? UnitsSettings.VerticalDistanceUnitsMeters : UnitsSettings.VerticalDistanceUnitsFeet
        }
        if (_unitsSettings.areaUnits.visible) {
            _unitsSettings.areaUnits.value = metric ? UnitsSettings.AreaUnitsSquareMeters : UnitsSettings.AreaUnitsSquareFeet
        }
        if (_unitsSettings.speedUnits.visible) {
            _unitsSettings.speedUnits.value = metric ? UnitsSettings.SpeedUnitsMetersPerSecond : UnitsSettings.SpeedUnitsFeetPerSecond
        }
        if (_unitsSettings.temperatureUnits.visible) {
            _unitsSettings.temperatureUnits.value = metric ? UnitsSettings.TemperatureUnitsCelsius : UnitsSettings.TemperatureUnitsFarenheit
        }
    }

    ColumnLayout {
        id:         settingsColumn
        spacing:    ScreenTools.defaultFontPixelHeight

        QGCLabel {
            id:         unitsSectionLabel
            text:       qsTr("选择您要使用的测量单位。您也可以在一般设置中稍后更改它。")

            Layout.preferredWidth: unitsGrid.width
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.preferredHeight: unitsGrid.height + (_margins * 2)
            Layout.preferredWidth:  unitsGrid.width + (_margins * 2)
            color:                  qgcPal.windowShade
            Layout.fillWidth:       true

            GridLayout {
                id:                 unitsGrid
                anchors.margins:    _margins
                anchors.top:        parent.top
                anchors.left:       parent.left
                rows:               _cVisibleFacts + 1
                flow:               GridLayout.TopToBottom

                QGCLabel { text: qsTr("单位制") }

                Repeater {
                    model: _rgFacts.length
                    QGCLabel {
                        text:       _rgLabels[index]
                        visible:    _rgFacts[index].visible
                    }
                }

                QGCComboBox {
                    Layout.fillWidth:   true
                    sizeToContents:     true
                    model:              [ qsTr("公制"), qsTr("英制") ]
                    currentIndex:       _unitsSettings.horizontalDistanceUnits.value === UnitsSettings.HorizontalDistanceUnitsMeters ? 0 : 1
                    onActivated: (index) => { changeSystemOfUnits(currentIndex === 0 /* metric */) }
                }

                Repeater {
                    id: unitComboBoxRepeater
                    model: _rgFacts.length
                    FactComboBox {
                        Layout.fillWidth:   true
                        sizeToContents:     true
                        fact:               _rgFacts[index]
                        indexModel:         false
                        visible:            _rgFacts[index].visible
                    }
                }
            }
        }
    }
}
