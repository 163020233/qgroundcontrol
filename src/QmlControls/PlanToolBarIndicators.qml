import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.UTMSP

// Toolbar for Plan View
Item {
    width: missionStats.width + _margins
    visible:false
    property var    planMasterController

    property var    _planMasterController:      planMasterController
    property var    _currentMissionItem:        _planMasterController.missionController.currentPlanViewItem ///< Mission item to display status for

    property var    missionItems:               _controllerValid ? _planMasterController.missionController.visualItems : undefined
    property real   missionPlannedDistance:     _controllerValid ? _planMasterController.missionController.missionPlannedDistance : NaN
    property real   missionTime:                _controllerValid ? _planMasterController.missionController.missionTime : 0
    property real   missionMaxTelemetry:        _controllerValid ? _planMasterController.missionController.missionMaxTelemetry : NaN
    property bool   missionDirty:               _controllerValid ? _planMasterController.missionController.dirty : false

    property bool   _controllerValid:           _planMasterController !== undefined && _planMasterController !== null
    property bool   _controllerOffline:         _controllerValid ? _planMasterController.offline : true
    property var    _controllerDirty:           _controllerValid ? _planMasterController.dirty : false
    property var    _controllerSyncInProgress:  _controllerValid ? _planMasterController.syncInProgress : false

    property bool   _currentMissionItemValid:   _currentMissionItem && _currentMissionItem !== undefined && _currentMissionItem !== null
    property bool   _curreItemIsFlyThrough:     _currentMissionItemValid && _currentMissionItem.specifiesCoordinate && !_currentMissionItem.isStandaloneCoordinate
    property bool   _currentItemIsVTOLTakeoff:  _currentMissionItemValid && _currentMissionItem.command == 84
    property bool   _missionValid:              missionItems !== undefined

    property real   _dataFontSize:              ScreenTools.defaultFontPointSize
    property real   _largeValueWidth:           ScreenTools.defaultFontPixelWidth * 8
    property real   _mediumValueWidth:          ScreenTools.defaultFontPixelWidth * 4
    property real   _smallValueWidth:           ScreenTools.defaultFontPixelWidth * 3
    property real   _labelToValueSpacing:       ScreenTools.defaultFontPixelWidth
    property real   _rowSpacing:                ScreenTools.isMobile ? 1 : 0
    property real   _distance:                  _currentMissionItemValid ? _currentMissionItem.distance : NaN
    property real   _altDifference:             _currentMissionItemValid ? _currentMissionItem.altDifference : NaN
    property real   _azimuth:                   _currentMissionItemValid ? _currentMissionItem.azimuth : NaN
    property real   _heading:                   _currentMissionItemValid ? _currentMissionItem.missionVehicleYaw : NaN
    property real   _missionPlannedDistance:    _missionValid ? missionPlannedDistance : NaN
    property real   _missionMaxTelemetry:       _missionValid ? missionMaxTelemetry : NaN
    property real   _missionTime:               _missionValid ? missionTime : 0
    property int    _batteryChangePoint:        _controllerValid ? _planMasterController.missionController.batteryChangePoint : -1
    property int    _batteriesRequired:         _controllerValid ? _planMasterController.missionController.batteriesRequired : -1
    property bool   _batteryInfoAvailable:      _batteryChangePoint >= 0 || _batteriesRequired >= 0
    property real   _gradient:                  _currentMissionItemValid && _currentMissionItem.distance > 0 ?
                                                    (_currentItemIsVTOLTakeoff ?
                                                         0 :
                                                         (Math.atan(_currentMissionItem.altDifference / _currentMissionItem.distance) * (180.0/Math.PI)))
                                                  : NaN

    property string _distanceText:                  isNaN(_distance) ?                  "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_distance).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property string _altDifferenceText:             isNaN(_altDifference) ?             "-.-" : QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(_altDifference).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
    property string _gradientText:                  isNaN(_gradient) ?                  "-.-" : _gradient.toFixed(0) + qsTr(" 度")
    property string _azimuthText:                   isNaN(_azimuth) ?                   "-.-" : Math.round(_azimuth) % 360
    property string _headingText:                   isNaN(_azimuth) ?                   "-.-" : Math.round(_heading) % 360
    property string _missionPlannedDistanceText:    isNaN(_missionPlannedDistance) ?    "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_missionPlannedDistance).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property string _missionMaxTelemetryText:       isNaN(_missionMaxTelemetry) ?       "-.-" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_missionMaxTelemetry).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property string _batteryChangePointText:        _batteryChangePoint < 0 ?           qsTr("N/A") : _batteryChangePoint
    property string _batteriesRequiredText:         _batteriesRequired < 0 ?            qsTr("N/A") : _batteriesRequired

    readonly property real _margins: ScreenTools.defaultFontPixelWidth

    // Properties of UTM adapter
    property bool   _utmspEnabled:                       QGroundControl.utmspSupported

    function getMissionTime() {
        if (!_missionTime) {
            return "00:00:00"
        }
        var t = new Date(2021, 0, 0, 0, 0, Number(_missionTime))
        var days = Qt.formatDateTime(t, 'dd')
        var complete

        if (days == 31) {
            days = '0'
            complete = Qt.formatTime(t, 'hh:mm:ss')
        } else {
            complete = days + " days " + Qt.formatTime(t, 'hh:mm:ss')
        }
        return complete
    }

    RowLayout {
        id:                     missionStats
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.leftMargin:     _margins
        anchors.left:           parent.left
        spacing:                ScreenTools.defaultFontPixelWidth * 2

        QGCButton {
            id:          uploadButton
            text:        _controllerDirty ? qsTr("必需上传") : qsTr("上传")
            enabled:     _utmspEnabled ? !_controllerSyncInProgress && UTMSPStateStorage.enableMissionUploadButton : !_controllerSyncInProgress
            visible:     !_controllerOffline && !_controllerSyncInProgress
            primary:     _controllerDirty
            onClicked: {
                if (_utmspEnabled) {
                    QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(true);
                    UTMSPStateStorage.removeFlightPlanState = true
                    UTMSPStateStorage.indicatorDisplayStatus = true
                }
                _planMasterController.upload();
            }

            PropertyAnimation on opacity {
                easing.type:    Easing.OutQuart
                from:           0.5
                to:             1
                loops:          Animation.Infinite
                running:        _controllerDirty && !_controllerSyncInProgress
                alwaysRunToEnd: true
                duration:       2000
            }
        }

        // === 当前航点 ===
        Rectangle {
            radius: 6
            color: Qt.rgba(0.2, 0.2, 0.2, 0.4)
            Layout.fillHeight: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 38
            anchors.verticalCenter: parent.verticalCenter
            // border.color: Qt.rgba(1, 1, 1, 0)
            anchors.margins: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                QGCLabel {
                    text: qsTr("当前航点")
                    font.bold: true
                    color: "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("高度差:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _altDifferenceText; color: "white"; font.pointSize: _dataFontSize }

                    QGCLabel { text: qsTr("方位:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _azimuthText; color: "white"; font.pointSize: _dataFontSize }

                    QGCLabel { text: qsTr("距离:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _distanceText; color: "white"; font.pointSize: _dataFontSize }
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("坡度:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _gradientText; color: "white"; font.pointSize: _dataFontSize }

                    QGCLabel { text: qsTr("航向:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _headingText; color: "white"; font.pointSize: _dataFontSize }
                }
            }
        }

        // === 总任务 ===
        Rectangle {
            radius: 6
            color: Qt.rgba(0.2, 0.2, 0.2, 0.4)
            Layout.fillHeight: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 32
            // border.color: Qt.rgba(1, 1, 1, 0)
            anchors.margins: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                QGCLabel {
                    text: qsTr("任务总览")
                    font.bold: true
                    color: "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("总距离:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _missionPlannedDistanceText; color: "white"; font.pointSize: _dataFontSize }

                    QGCLabel { text: qsTr("最大遥测:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _missionMaxTelemetryText; color: "white"; font.pointSize: _dataFontSize }

                    QGCLabel { text: qsTr("时间:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: getMissionTime(); color: "white"; font.pointSize: _dataFontSize }
                }
            }
        }

        // === 电池 ===
        Rectangle {
            radius: 6
            color: Qt.rgba(0.2, 0.2, 0.2, 0.5)
            Layout.fillHeight: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
            // border.color: Qt.rgba(1, 1, 1, 0)
            visible: _batteryInfoAvailable
            anchors.margins: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                QGCLabel {
                    text: qsTr("电池状态")
                    font.bold: true
                    color: "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("需求:"); color: "#DDDDDD"; font.pointSize: _dataFontSize }
                    QGCLabel { text: _batteriesRequiredText; color: "white"; font.pointSize: _dataFontSize }
                }
            }
        }
        Item { Layout.fillWidth: true } // 填充剩余空间
    }
}

