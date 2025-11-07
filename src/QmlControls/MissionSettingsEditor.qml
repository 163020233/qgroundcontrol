import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.SettingsManager
import QGroundControl.Controllers

// Editor for Mission Settings
Rectangle {
    id:                 valuesRect
    width:              availableWidth
    height:             valuesColumn.height + (_margin * 2)
    // color:              qgcPal.windowShadeDark
    color:              Qt.rgba(0.2, 0.2, 0.2, 0.4)
    visible:            missionItem.isCurrentItem
    radius:             _radius

    property var    _masterControler:               masterController
    property var    _missionController:             _masterControler.missionController
    property var    _controllerVehicle:             _masterControler.controllerVehicle
    property bool   _vehicleHasHomePosition:        _controllerVehicle.homePosition.isValid
    property bool   _showCruiseSpeed:               !_controllerVehicle.multiRotor
    property bool   _showHoverSpeed:                _controllerVehicle.multiRotor || _controllerVehicle.vtol
    property bool   _multipleFirmware:              !QGroundControl.singleFirmwareSupport
    property bool   _multipleVehicleTypes:          !QGroundControl.singleVehicleSupport
    property real   _fieldWidth:                    ScreenTools.defaultFontPixelWidth * 16
    property bool   _mobile:                        ScreenTools.isMobile
    property var    _savePath:                      QGroundControl.settingsManager.appSettings.missionSavePath
    property var    _fileExtension:                 QGroundControl.settingsManager.appSettings.missionFileExtension
    property var    _appSettings:                   QGroundControl.settingsManager.appSettings
    property bool   _waypointsOnlyMode:             QGroundControl.corePlugin.options.missionWaypointsOnly
    property bool   _showCameraSection:             (_waypointsOnlyMode || QGroundControl.corePlugin.showAdvancedUI) && !_controllerVehicle.apmFirmware
    property bool   _simpleMissionStart:            QGroundControl.corePlugin.options.showSimpleMissionStart
    property bool   _showFlightSpeed:               !_controllerVehicle.vtol && !_simpleMissionStart && !_controllerVehicle.apmFirmware
    property bool   _allowFWVehicleTypeSelection:   _noMissionItemsAdded && !globals.activeVehicle

    readonly property string _firmwareLabel:    qsTr("固件")
    readonly property string _vehicleLabel:     qsTr("设备")
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth / 2

    QGCPalette { id: qgcPal }
    QGCFileDialogController { id: fileController }
    Component { id: altModeDialogComponent; AltModeDialog { } }

    Connections {
        target: _controllerVehicle
        function onSupportsTerrainFrameChanged() {
            if (!_controllerVehicle.supportsTerrainFrame && _missionController.globalAltitudeMode === QGroundControl.AltitudeModeTerrainFrame) {
                _missionController.globalAltitudeMode = QGroundControl.AltitudeModeCalcAboveTerrain
            }
        }
    }

    ColumnLayout {
        id:                 valuesColumn
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        spacing:            _margin

        QGCLabel {
            text:           qsTr("所有高度")
            font.pointSize: ScreenTools.smallFontPointSize
        }
        MouseArea {
            Layout.preferredWidth:  childrenRect.width
            Layout.preferredHeight: childrenRect.height

            onClicked: {
                var removeModes = []
                var updateFunction = function(altMode){ _missionController.globalAltitudeMode = altMode }
                if (!_controllerVehicle.supportsTerrainFrame) {
                    removeModes.push(QGroundControl.AltitudeModeTerrainFrame)
                }
                if (!_noMissionItemsAdded) {
                    if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeRelative) {
                        removeModes.push(QGroundControl.AltitudeModeRelative)
                    }
                    if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeAbsolute) {
                        removeModes.push(QGroundControl.AltitudeModeAbsolute)
                    }
                    if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeCalcAboveTerrain) {
                        removeModes.push(QGroundControl.AltitudeModeCalcAboveTerrain)
                    }
                    if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeTerrainFrame) {
                        removeModes.push(QGroundControl.AltitudeModeTerrainFrame)
                    }
                }
                altModeDialogComponent.createObject(mainWindow, { rgRemoveModes: removeModes, updateAltModeFn: updateFunction }).open()
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    id: altModeLabel
                    text: {
                        switch (_missionController.globalAltitudeMode) {
                            case QGroundControl.AltitudeModeMixed:
                                return "混合模式"
                            case QGroundControl.AltitudeModeRelative:
                                return "相对高度"
                            case QGroundControl.AltitudeModeAbsolute:
                                return "绝对高度"
                            case QGroundControl.AltitudeModeCalcAboveTerrain:
                                return "计算高度"
                            case QGroundControl.AltitudeModeTerrainFrame:
                                return "跟随地形"
                            case QGroundControl.AltitudeModeNone:
                                return "无高度模式"
                            default:
                                return "未知模式"
                        }
                    }
                }

                //
                // QGCLabel {
                //     id:     altModeLabel
                //     text:   QGroundControl.altitudeModeShortDescription(_missionController.globalAltitudeMode)
                // }
                QGCColoredImage {
                    height:     ScreenTools.defaultFontPixelHeight / 2
                    width:      height
                    source:     "/res/DropArrow.svg"
                    color:      altModeLabel.color
                }
            }
        }

        QGCLabel {
            text:           qsTr("初始项目高度")
            font.pointSize: ScreenTools.smallFontPointSize
        }
        FactTextField {
            fact:               QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude
            Layout.fillWidth:   true
        }

        GridLayout {
            Layout.fillWidth:   true
            columnSpacing:      ScreenTools.defaultFontPixelWidth
            rowSpacing:         columnSpacing
            columns:            2

            QGCCheckBox {
                id:         flightSpeedCheckBox
                text:       qsTr("飞行速度")
                visible:    _showFlightSpeed
                checked:    missionItem.speedSection.specifyFlightSpeed
                onClicked:   missionItem.speedSection.specifyFlightSpeed = checked
            }
            FactTextField {
                Layout.fillWidth:   true
                fact:               missionItem.speedSection.flightSpeed
                visible:            _showFlightSpeed
                enabled:            flightSpeedCheckBox.checked
            }
        }

        Column {
            Layout.fillWidth:   true
            spacing:            _margin
            visible:            !_simpleMissionStart

            CameraSection {
                id:         cameraSection
                checked:    !_waypointsOnlyMode && missionItem.cameraSection.settingsSpecified
                visible:    _showCameraSection
            }

            QGCLabel {
                anchors.left:           parent.left
                anchors.right:          parent.right
                text:                   qsTr("相机命令将在项目启动时立即生效。")
                wrapMode:               Text.WordWrap
                horizontalAlignment:    Text.AlignHCenter
                font.pointSize:         ScreenTools.smallFontPointSize
                visible:                _showCameraSection && cameraSection.checked
            }

            SectionHeader {
                id:             vehicleInfoSectionHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                text:           qsTr("设备信息")
                // visible:        !_waypointsOnlyMode
                visible:false
                checked:        false
            }

            GridLayout {
                anchors.left:   parent.left
                anchors.right:  parent.right
                columnSpacing:  ScreenTools.defaultFontPixelWidth
                rowSpacing:     columnSpacing
                columns:        2
                visible:        vehicleInfoSectionHeader.visible && vehicleInfoSectionHeader.checked

                QGCLabel {
                    text:               _firmwareLabel
                    Layout.fillWidth:   true
                    visible:            _multipleFirmware
                }
                FactComboBox {
                    fact:                   QGroundControl.settingsManager.appSettings.offlineEditingFirmwareClass
                    indexModel:             false
                    Layout.preferredWidth:  _fieldWidth
                    visible:                _multipleFirmware && _allowFWVehicleTypeSelection
                }
                QGCLabel {
                    text:       _controllerVehicle.firmwareTypeString
                    visible:    _multipleFirmware && !_allowFWVehicleTypeSelection
                }

                QGCLabel {
                    text:               _vehicleLabel
                    Layout.fillWidth:   true
                    visible:            _multipleVehicleTypes
                }
                FactComboBox {
                    fact:                   QGroundControl.settingsManager.appSettings.offlineEditingVehicleClass
                    indexModel:             false
                    Layout.preferredWidth:  _fieldWidth
                    visible:                _multipleVehicleTypes && _allowFWVehicleTypeSelection
                }
                QGCLabel {
                    text:       _controllerVehicle.vehicleTypeString
                    visible:    _multipleVehicleTypes && !_allowFWVehicleTypeSelection
                }

                QGCLabel {
                    Layout.columnSpan:      2
                    Layout.alignment:       Qt.AlignHCenter
                    Layout.fillWidth:       true
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    text:                   qsTr("以下速度值用于计算总项目时间。它们不会影响项目的飞行速度。")
                    visible:                _showCruiseSpeed || _showHoverSpeed
                }

                QGCLabel {
                    text:               qsTr("巡航速度")
                    visible:            _showCruiseSpeed
                    Layout.fillWidth:   true
                }
                FactTextField {
                    fact:                   QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed
                    visible:                _showCruiseSpeed
                    Layout.preferredWidth:  _fieldWidth
                }

                QGCLabel {
                    text:               qsTr("悬停速度")
                    visible:            _showHoverSpeed
                    Layout.fillWidth:   true
                }
                FactTextField {
                    fact:                   QGroundControl.settingsManager.appSettings.offlineEditingHoverSpeed
                    visible:                _showHoverSpeed
                    Layout.preferredWidth:  _fieldWidth
                }
            } // GridLayout

            SectionHeader {
                id:             plannedHomePositionSection
                anchors.left:   parent.left
                anchors.right:  parent.right
                text:           qsTr("启动位置")
                visible:        !_vehicleHasHomePosition
                checked:        false
            }

            Column {
                anchors.left:   parent.left
                anchors.right:  parent.right
                spacing:        _margin
                visible:        plannedHomePositionSection.checked && !_vehicleHasHomePosition

                GridLayout {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    columnSpacing:  ScreenTools.defaultFontPixelWidth
                    rowSpacing:     columnSpacing
                    columns:        2

                    QGCLabel {
                        text: qsTr("高度")
                    }
                    FactTextField {
                        fact:               missionItem.plannedHomePositionAltitude
                        Layout.fillWidth:   true
                    }
                }

                QGCLabel {
                    width:                  parent.width
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    text:                   qsTr("飞行时车辆设定的实际位置。")
                    horizontalAlignment:    Text.AlignHCenter
                }

                QGCButton {
                    text:                       qsTr("设置为地图中心")
                    onClicked:                  missionItem.coordinate = map.center
                    anchors.horizontalCenter:   parent.horizontalCenter
                }
            }
        } // Column
    } // Column
} // Rectangle
