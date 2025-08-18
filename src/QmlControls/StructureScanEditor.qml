import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.FlightMap

// Editor for Survery mission items
Rectangle {
    id:         _root
    height:     visible ? (editorColumn.height + (_margin * 2)) : 0
    width:      availableWidth
    color:      qgcPal.windowShadeDark
    radius:     _radius

    // The following properties must be available up the hierarchy chain
    //property real   availableWidth    ///< Width for control
    //property var    missionItem       ///< Mission Item for editor

    property real   _margin:                    ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:                ScreenTools.defaultFontPixelWidth * 10.5
    property var    _vehicle:                   QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property real   _cameraMinTriggerInterval:  missionItem.cameraCalc.minTriggerInterval.rawValue

    function polygonCaptureStarted() {
        missionItem.clearPolygon()
    }

    function polygonCaptureFinished(coordinates) {
        for (var i=0; i<coordinates.length; i++) {
            missionItem.addPolygonCoordinate(coordinates[i])
        }
    }

    function polygonAdjustVertex(vertexIndex, vertexCoordinate) {
        missionItem.adjustPolygonCoordinate(vertexIndex, vertexCoordinate)
    }

    function polygonAdjustStarted() { }
    function polygonAdjustFinished() { }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    ColumnLayout {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right

        QGCLabel {
                id:                 wizardLabel
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                horizontalAlignment:    Text.AlignHCenter
                text:               qsTr("使用多边形工具创建多边形，该多边形表示结构的轮廓。")
                visible:        !missionItem.structurePolygon.isValid || missionItem.wizardMode
            }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:        _margin
            visible:        !wizardLabel.visible

            QGCTabBar {
                id:             tabBar
                Layout.fillWidth:   true

                Component.onCompleted: currentIndex = 0

                QGCTabButton { text: qsTr("网格") }
                QGCTabButton { text: qsTr("相机") }
            }

            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex == 0

                QGCLabel {
                    Layout.fillWidth:   true
                    text:           qsTr("注意：多边形表示结构表面，而不是设备飞行路径。")
                    wrapMode:       Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    text:           qsTr("警告：照片间隔低于相机支持的最小间隔（%1 秒）。").arg(_cameraMinTriggerInterval.toFixed(1))
                    wrapMode:       Text.WordWrap
                    color:          qgcPal.warningText
                    visible:        missionItem.cameraShots > 0 && _cameraMinTriggerInterval !== 0 && _cameraMinTriggerInterval > missionItem.timeBetweenShots
                }

                CameraCalcGrid {
                    Layout.fillWidth:   true
                    cameraCalc:                     missionItem.cameraCalc
                    vehicleFlightIsFrontal:         false
                    distanceToSurfaceLabel:         qsTr("扫描距离")
                    frontalDistanceLabel:           qsTr("层高")
                    sideDistanceLabel:              qsTr("触发距离")
                }

                SectionHeader {
                    id:             scanHeader
                    Layout.fillWidth:   true
                    text:           qsTr("扫描")
                }

                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:        _margin
                    visible:        scanHeader.checked

                    GridLayout {
                        Layout.fillWidth:   true
                        columnSpacing:  _margin
                        rowSpacing:     _margin
                        columns:        2

                        FactComboBox {
                            fact:               missionItem.startFromTop
                            indexModel:         true
                            model:              [ qsTr("从底部开始扫描"), qsTr("从顶部开始扫描") ]
                            Layout.columnSpan:  2
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text:       qsTr("结构高度")
                        }
                        FactTextField {
                            fact:               missionItem.structureHeight
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("扫描底部高度") }
                        AltitudeFactTextField {
                            fact:               missionItem.scanBottomAlt
                            altitudeMode:       QGroundControl.AltitudeModeRelative
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("入口/出口高度") }
                        AltitudeFactTextField {
                            fact:               missionItem.entranceAlt
                            altitudeMode:       QGroundControl.AltitudeModeRelative
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text:       qsTr("相机俯仰角")
                            visible:    missionItem.cameraCalc.isManualCamera
                        }
                        FactTextField {
                            fact:               missionItem.gimbalPitch
                            Layout.fillWidth:   true
                            visible:            missionItem.cameraCalc.isManualCamera
                        }
                    }

                    Item {
                        height: ScreenTools.defaultFontPixelHeight / 2
                        width:  1
                    }

                    QGCButton {
                        text:       qsTr("旋转入口点")
                        onClicked:  missionItem.rotateEntryPoint()
                    }
                } // Column - Scan

                SectionHeader {
                    id:             statsHeader
                    Layout.fillWidth:   true
                    text:           qsTr("统计信息")
                }

                Grid {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth
                    visible:        statsHeader.checked

                    QGCLabel { text: qsTr("层数") }
                    QGCLabel { text: missionItem.layers.valueString }

                    QGCLabel { text: qsTr("层高度") }
                    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintFrontal.valueString + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }

                    QGCLabel { text: qsTr("顶部层高度") }
                    QGCLabel { text: QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(missionItem.topFlightAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }

                    QGCLabel { text: qsTr("底部层高度") }
                    QGCLabel { text: QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(missionItem.bottomFlightAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }

                    QGCLabel { text: qsTr("照片数量") }
                    QGCLabel { text: missionItem.cameraShots }

                    QGCLabel { text: qsTr("照片间隔") }
                    QGCLabel { text: missionItem.timeBetweenShots.toFixed(1) + " " + qsTr("秒") }

                    QGCLabel { text: qsTr("触发距离") }
                    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintSide.valueString + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }
                }
            } // Grid Column

            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex == 1

                CameraCalcCamera {
                    Layout.fillWidth:   true
                    cameraCalc: missionItem.cameraCalc
                }
            }
        }
    }
}
