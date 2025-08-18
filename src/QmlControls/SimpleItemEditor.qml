import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette

// Editor for Simple mission items
Rectangle {
    width:  availableWidth
    height: editorColumn.height + (_margin * 2)
    color:  qgcPal.windowShadeDark
    radius: _radius

    property bool _specifiesAltitude:       missionItem.specifiesAltitude
    property real _margin:                  ScreenTools.defaultFontPixelHeight / 2
    property real _altRectMargin:           ScreenTools.defaultFontPixelWidth / 2
    property var  _controllerVehicle:       missionItem.masterController.controllerVehicle
    property int  _globalAltMode:           missionItem.masterController.missionController.globalAltitudeMode
    property bool _globalAltModeIsMixed:    _globalAltMode == QGroundControl.AltitudeModeMixed
    property real _radius:                  ScreenTools.defaultFontPixelWidth / 2

    function updateAltitudeModeText() {
        if (missionItem.altitudeMode === QGroundControl.AltitudeModeRelative) {
            altModeLabel.text = QGroundControl.altitudeModeShortDescription(QGroundControl.AltitudeModeRelative)
        } else if (missionItem.altitudeMode === QGroundControl.AltitudeModeAbsolute) {
            altModeLabel.text = QGroundControl.altitudeModeShortDescription(QGroundControl.AltitudeModeAbsolute)
        } else if (missionItem.altitudeMode === QGroundControl.AltitudeModeCalcAboveTerrain) {
            altModeLabel.text = QGroundControl.altitudeModeShortDescription(QGroundControl.AltitudeModeCalcAboveTerrain)
        } else if (missionItem.altitudeMode === QGroundControl.AltitudeModeTerrainFrame) {
            altModeLabel.text = QGroundControl.altitudeModeShortDescription(QGroundControl.AltitudeModeTerrainFrame)
        } else {
            altModeLabel.text = qsTr("内部错误")
        }
    }

    Component.onCompleted: updateAltitudeModeText()

    Connections {
        target:                 missionItem
        onAltitudeModeChanged:  updateAltitudeModeText()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    Component { id: altModeDialogComponent; AltModeDialog { } }

    Column {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        spacing:            _margin

        QGCLabel {
            width:          parent.width
            wrapMode:       Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            text:           missionItem.rawEdit ?
                                qsTr("提供对所有命令/参数的高级访问。请非常小心！") :
                                missionItem.commandDescription
        }

        ColumnLayout {
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _margin
            visible:            missionItem.isTakeoffItem && missionItem.wizardMode // Hack special case for takeoff item

            QGCLabel {
                text:               qsTr("Move '%1' %2 to the %3 location. %4")
                .arg(_controllerVehicle.vtol ? qsTr("T") : qsTr("T"))
                .arg(_controllerVehicle.vtol ? qsTr("转换方向") : qsTr("起飞"))
                .arg(_controllerVehicle.vtol ? qsTr("期望") : qsTr("爬升"))
                .arg(_controllerVehicle.vtol ? (qsTr("确保从启动到转换方向的距离足够远以完成转换。")) : "")
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                visible:            !initialClickLabel.visible
            }

            QGCLabel {
                text:               qsTr("确保没有障碍物并且迎风飞行。")
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                visible:            !initialClickLabel.visible
            }

            QGCButton {
                text:               qsTr("完成")
                Layout.fillWidth:   true
                visible:            !initialClickLabel.visible
                onClicked: {
                    missionItem.wizardMode = false
                }
            }

            QGCLabel {
                id:                 initialClickLabel
                text:               missionItem.launchTakeoffAtSameLocation ?
                                        qsTr("点击地图设置计划起飞位置。") :
                                        qsTr("点击地图设置计划启动位置。")
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                visible:            missionItem.isTakeoffItem && !missionItem.launchCoordinate.isValid
            }
        }

        Column {
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _altRectMargin
            visible:            !missionItem.wizardMode

            ColumnLayout {
                anchors.left:   parent.left
                anchors.right:  parent.right
                spacing:        0
                visible:        _specifiesAltitude

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.smallFontPointSize
                    text:               qsTr("下方高度指定地面的大致高度。通常情况下，返回原始发射位置时的高度为 0。")
                    visible:            missionItem.isLandCommand
                }

                MouseArea {
                    Layout.preferredWidth:  childrenRect.width
                    Layout.preferredHeight: childrenRect.height

                    onClicked: {
                        if (_globalAltModeIsMixed) {
                            var removeModes = []
                            var updateFunction = function(altMode){ missionItem.altitudeMode = altMode }
                            if (!_controllerVehicle.supportsTerrainFrame) {
                                removeModes.push(QGroundControl.AltitudeModeTerrainFrame)
                            }
                            if (!QGroundControl.corePlugin.options.showMissionAbsoluteAltitude && missionItem.altitudeMode !== QGroundControl.AltitudeModeAbsolute) {
                                removeModes.push(QGroundControl.AltitudeModeAbsolute)
                            }
                            removeModes.push(QGroundControl.AltitudeModeMixed)
                            altModeDialogComponent.createObject(mainWindow, { rgRemoveModes: removeModes, updateAltModeFn: updateFunction }).open()
                        }
                    }

                    RowLayout {
                        spacing: _altRectMargin

                        QGCLabel {
                            Layout.alignment:   Qt.AlignBaseline
                            text:               qsTr("高度")
                            font.pointSize:     ScreenTools.smallFontPointSize
                        }
                        QGCLabel {
                            id:                 altModeLabel
                            Layout.alignment:   Qt.AlignBaseline
                            visible:            _globalAltMode !== QGroundControl.AltitudeModeRelative
                        }
                        QGCColoredImage {
                            height:     ScreenTools.defaultFontPixelHeight / 2
                            width:      height
                            source:     "/res/DropArrow.svg"
                            color:      qgcPal.text
                            visible:    _globalAltModeIsMixed
                        }
                    }
                }

                FactTextField {
                    id:                 altField
                    Layout.fillWidth:   true
                    fact:               missionItem.altitude
                }

                QGCLabel {
                    font.pointSize:     ScreenTools.smallFontPointSize
                    text:               qsTr("实际 AMSL 高度发送：%1 %2").arg(missionItem.amslAltAboveTerrain.valueString).arg(missionItem.amslAltAboveTerrain.units)
                    visible:            missionItem.altitudeMode === QGroundControl.AltitudeModeCalcAboveTerrain
                }
            }

            ColumnLayout {
                anchors.left:   parent.left
                anchors.right:  parent.right
                spacing:        _margin

                Repeater {
                    model: missionItem.comboboxFacts

                    ColumnLayout {
                        Layout.fillWidth:   true
                        spacing:            0

                        QGCLabel {
                            font.pointSize: ScreenTools.smallFontPointSize
                            text:           object.name
                            visible:        object.name !== ""
                        }

                        FactComboBox {
                            Layout.fillWidth:   true
                            indexModel:         false
                            model:              object.enumStrings
                            fact:               object
                        }
                    }
                }
            }

            GridLayout {
                anchors.left:   parent.left
                anchors.right:  parent.right
                flow:           GridLayout.TopToBottom
                rows:           missionItem.textFieldFacts.count +
                                missionItem.nanFacts.count +
                                (missionItem.speedSection.available ? 1 : 0)
                columns:        2

                Repeater {
                    model: missionItem.textFieldFacts

                    QGCLabel { text: object.name }
                }

                Repeater {
                    model: missionItem.nanFacts

                    QGCCheckBox {
                        text:           object.name
                        checked:        !isNaN(object.rawValue)
                        onClicked:      object.rawValue = checked ? 0 : NaN
                    }
                }

                QGCCheckBox {
                    id:         flightSpeedCheckbox
                    text:       qsTr("飞行速度")
                    checked:    missionItem.speedSection.specifyFlightSpeed
                    onClicked:  missionItem.speedSection.specifyFlightSpeed = checked
                    visible:    missionItem.speedSection.available
                }


                Repeater {
                    model: missionItem.textFieldFacts

                    FactTextField {
                        showUnits:          true
                        fact:               object
                        Layout.fillWidth:   true
                        enabled:            !object.readOnly
                    }
                }

                Repeater {
                    model: missionItem.nanFacts

                    FactTextField {
                        showUnits:          true
                        fact:               object
                        Layout.fillWidth:   true
                        enabled:            !isNaN(object.rawValue)
                    }
                }

                FactTextField {
                    fact:               missionItem.speedSection.flightSpeed
                    Layout.fillWidth:   true
                    enabled:            flightSpeedCheckbox.checked
                    visible:            missionItem.speedSection.available
                }
            }

            CameraSection {
                checked:    missionItem.cameraSection.settingsSpecified
                visible:    missionItem.cameraSection.available
            }
        }
    }
}
