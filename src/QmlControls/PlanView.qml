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
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.FlightMap
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Palette
import QGroundControl.Controllers
import QGroundControl.ShapeFileHelper
import QGroundControl.FlightDisplay
import QGroundControl.UTMSP


Item {
    id: _root

    property bool planControlColapsed: false

    readonly property int   _decimalPlaces:             8
    readonly property real  _margin:                    ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _toolsMargin:               ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real  _radius:                    ScreenTools.defaultFontPixelWidth  * 0.5
    readonly property real  _rightPanelWidth:           Math.min(width / 3, ScreenTools.defaultFontPixelWidth * 30)
    readonly property var   _defaultVehicleCoordinate:  QtPositioning.coordinate(37.803784, -122.462276)
    readonly property bool  _waypointsOnlyMode:         QGroundControl.corePlugin.options.missionWaypointsOnly

    property var    _planMasterController:              planMasterController
    property var    _missionController:                 _planMasterController.missionController
    property var    _geoFenceController:                _planMasterController.geoFenceController
    property var    _rallyPointController:              _planMasterController.rallyPointController
    property var    _visualItems:                       _missionController.visualItems
    property bool   _lightWidgetBorders:                editorMap.isSatelliteMap
    property bool   _addROIOnClick:                     false
    property bool   _singleComplexItem:                 _missionController.complexMissionItemNames.length === 1
     property int    _editingLayer:                      {if(!_utmspEnabled){layerTabBar.currentIndex ? _layers[layerTabBar.currentIndex] : _layerMission}else{layerTabBarUTMSP.currentIndex ? _layersUTMSP[layerTabBarUTMSP.currentIndex] : _layerMission}}
    property int    _toolStripBottom:                   toolStrip.height + toolStrip.y
    property var    _appSettings:                       QGroundControl.settingsManager.appSettings
    property var    _planViewSettings:                  QGroundControl.settingsManager.planViewSettings
    property bool   _promptForPlanUsageShowing:         false
    property bool   _utmspEnabled:                      QGroundControl.utmspSupported
    property bool   _resetGeofencePolygon:              false   //Reset the Geofence Polygon
    property var    _vehicleID
    property bool   _triggerSubmit
    property bool   _resetRegisterFlightPlan

    readonly property var       _layers:                    [_layerMission, _layerGeoFence, _layerRallyPoints]
    readonly property var       _layersUTMSP:               [_layerMission, _layerRallyPoints, _layerUTMSP] //Adds additional UTMSP layer

    readonly property int       _layerMission:              1
    readonly property int       _layerGeoFence:             2
    readonly property int       _layerRallyPoints:          3
    readonly property int       _layerUTMSP:                4 // Additional Tab button when UTMSP is enabled
    readonly property string    _armedVehicleUploadPrompt:  qsTr("设备当前已启动。您是否要将计划上传到设备？")


    function mapCenter() {
        var coordinate = editorMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    property bool _firstMissionLoadComplete:    false
    property bool _firstFenceLoadComplete:      false
    property bool _firstRallyLoadComplete:      false
    property bool _firstLoadComplete:           false

    MapFitFunctions {
        id:                         mapFitFunctions  // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map:                        editorMap
        usePlannedHomePosition:     true
        planMasterController:       _planMasterController
    }

    onVisibleChanged: {
        if(visible) {
            editorMap.zoomLevel = QGroundControl.flightMapZoom
            editorMap.center    = QGroundControl.flightMapPosition
            if (!_planMasterController.containsItems) {
                toolStrip.simulateClick(toolStrip.fileButtonIndex)
            }
        }
    }

    Connections {
        target: _appSettings ? _appSettings.defaultMissionItemAltitude : null
        function onRawValueChanged() {
            if (_visualItems.count > 1) {
                mainWindow.showMessageDialog(qsTr("应用新的高度"),
                                             qsTr("您已更改了计划项目的默认高度。是否要将该高度应用于当前计划中的所有项目？"),
                                             Dialog.Yes | Dialog.No,
                                             function() { _missionController.applyDefaultMissionAltitude() })
            }
        }
    }

    Component {
        id: promptForPlanUsageOnVehicleChangePopupComponent
        QGCPopupDialog {
            title:      _planMasterController.managerVehicle.isOfflineEditingVehicle ? qsTr("计划视图 - 设备已断开") : qsTr("计划视图 - 设备已更改")
            buttons:    Dialog.NoButton

            ColumnLayout {
                QGCLabel {
                    Layout.maximumWidth:    parent.width
                    wrapMode:               QGCLabel.WordWrap
                    text:                   _planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                                qsTr("与计划视图中的计划关联的设备不再可用。您想对该计划做什么？") :
                                                qsTr("计划视图中正在处理的计划不是当前设备的计划。您想对该计划做什么？")
                }

                QGCButton {
                    Layout.fillWidth:   true
                    text:               _planMasterController.dirty ?
                                            (_planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                                 qsTr("放弃未保存的更改") :
                                                 qsTr("放弃未保存的更改，从设备加载新计划")) :
                                            qsTr("从设备加载新计划")
                    onClicked: {
                        _planMasterController.showPlanFromManagerVehicle()
                        _promptForPlanUsageShowing = false
                        close();
                    }
                }

                QGCButton {
                    Layout.fillWidth:   true
                    text:               _planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                            qsTr("保留当前计划") :
                                            qsTr("保留当前计划，不从设备更新")
                    onClicked: {
                        if (!_planMasterController.managerVehicle.isOfflineEditingVehicle) {
                            _planMasterController.dirty = true
                        }
                        _promptForPlanUsageShowing = false
                        close()
                    }
                }
            }
        }
    }

    PlanMasterController {
        id:         planMasterController
        flyView:    false

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }

        onPromptForPlanUsageOnVehicleChange: {
            if (!_promptForPlanUsageShowing) {
                _promptForPlanUsageShowing = true
                promptForPlanUsageOnVehicleChangePopupComponent.createObject(mainWindow).open()
            }
        }

        function waitingOnIncompleteDataMessage(save) {
            var saveOrUpload = save ? qsTr("保存") : qsTr("上传")
            mainWindow.showMessageDialog(qsTr("无法 %1").arg(saveOrUpload), qsTr("计划包含不完整的项目。完成所有项目后再次 %1。").arg(saveOrUpload))
        }

        function waitingOnTerrainDataMessage(save) {
            var saveOrUpload = save ? qsTr("保存") : qsTr("上传")
            mainWindow.showMessageDialog(qsTr("无法 %1").arg(saveOrUpload), qsTr("计划正在等待服务器的地形数据以获取正确的高度值。"))
        }

        function checkReadyForSaveUpload(save) {
            if (readyForSaveState() == VisualMissionItem.NotReadyForSaveData) {
                waitingOnIncompleteDataMessage(save)
                return false
            } else if (readyForSaveState() == VisualMissionItem.NotReadyForSaveTerrain) {
                waitingOnTerrainDataMessage(save)
                return false
            }
            return true
        }

        function upload() {
            if (!checkReadyForSaveUpload(false /* save */)) {
                return
            }
            switch (_missionController.sendToVehiclePreCheck()) {
                case MissionController.SendToVehiclePreCheckStateOk:
                    sendToVehicle()
                    break
                case MissionController.SendToVehiclePreCheckStateActiveMission:
                    mainWindow.showMessageDialog(qsTr("上传"), qsTr("当前计划必须先暂停，才能上传新计划"))
                    break
                case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
                    mainWindow.showMessageDialog(qsTr("计划上传"),
                                                 qsTr("此计划是为不同的固件或设备类型创建的，与您要上传到的设备的固件/设备类型不匹配。 " +
                                                      "这可能会导致错误或不正确的行为。 " +
                                                      "建议重新创建计划以匹配正确的固件/设备类型。\n\n" +
                                                      "点击 '确定' 继续上传计划。"),
                                                 Dialog.Ok | Dialog.Cancel,
                                                 function() { _planMasterController.sendToVehicle() })
                    break
            }
        }

        function loadFromSelectedFile() {
            fileDialog.title =          qsTr("选择计划文件")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.loadNameFilters
            fileDialog.openForLoad()
        }

        function saveToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            fileDialog.title =          qsTr("保存计划")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.saveNameFilters
            fileDialog.openForSave()
        }

        function fitViewportToItems() {
            mapFitFunctions.fitMapViewportToMissionItems()
        }

        function saveKmlToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            fileDialog.title =          qsTr("保存KML")
            fileDialog.planFiles =      false
            fileDialog.nameFilters =    ShapeFileHelper.fileDialogKMLFilters
            fileDialog.openForSave()
        }
    }

    Connections {
        target: _missionController

        function onNewItemsFromVehicle() {
            if (_visualItems && _visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
            }
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
    }

    function insertSimpleItemAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertSimpleMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertROIAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertROIMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertCancelROIAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertCancelROIMissionItem(nextIndex, true /* makeCurrentItem */)
    }

    function insertComplexItemAfterCurrent(complexItemName) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertTakeItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertTakeoffItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertLandItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }


    function selectNextNotReady() {
        var foundCurrent = false
        for (var i=0; i<_missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true    ///< true: working with plan files, false: working with kml file

        onAcceptedForSave: (file) => {
            if (planFiles) {
                _planMasterController.saveToFile(file)
            } else {
                _planMasterController.saveToKml(file)
            }
            close()
        }

        onAcceptedForLoad: (file) => {
            _planMasterController.loadFromFile(file)
            _planMasterController.fitViewportToItems()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }

    PlanViewToolBar {
        id:                     planToolBar
        planMasterController:   _planMasterController
        color:"transparent"
    }

    Item {
        id:             panel
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    planToolBar.bottom
        anchors.bottom: parent.bottom

        FlightMap {
            id:                         editorMap
            anchors.fill:               parent
            mapName:                    "MissionEditor"
            allowGCSLocationCenter:     true
            allowVehicleLocationCenter: true
            planView:                   true

            zoomLevel:                  QGroundControl.flightMapZoom
            center:                     QGroundControl.flightMapPosition

            // This is the center rectangle of the map which is not obscured by tools
            property rect centerViewport:   Qt.rect(_leftToolWidth + _margin,  _margin, editorMap.width - _leftToolWidth - _rightToolWidth - (_margin * 2), (terrainStatus.visible ? terrainStatus.y : height - _margin) - _margin)

            property real _leftToolWidth:       toolStrip.x + toolStrip.width
            property real _rightToolWidth:      rightPanel.width + rightPanel.anchors.rightMargin
            property real _nonInteractiveOpacity:  0.5

            // Initial map position duplicates Fly view position
            Component.onCompleted: editorMap.center = QGroundControl.flightMapPosition

            QGCMapPalette { id: mapPal; lightColors: editorMap.isSatelliteMap }

            onZoomLevelChanged: {
                QGroundControl.flightMapZoom = editorMap.zoomLevel
            }
            onCenterChanged: {
                QGroundControl.flightMapPosition = editorMap.center
            }

            onMapClicked: (mouse) => {
                // Take focus to close any previous editing
                editorMap.focus = true
                if (!mainWindow.allowViewSwitch()) {
                    return
                }
                var coordinate = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */)
                coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
                coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
                coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)
				if(_utmspEnabled){
                	QGroundControl.utmspManager.utmspVehicle.updateLastCoordinates(coordinate.latitude, coordinate.longitude)
                }
                
                switch (_editingLayer) {
                case _layerMission:
                    if (addWaypointRallyPointAction.checked) {
                        insertSimpleItemAfterCurrent(coordinate)
                    } else if (_addROIOnClick) {
                        insertROIAfterCurrent(coordinate)
                        _addROIOnClick = false
                    }

                    break
                case _layerRallyPoints:
                    if (_rallyPointController.supported && addWaypointRallyPointAction.checked) {
                        _rallyPointController.addPoint(coordinate)
                    }
                    break

                case _layerUTMSP:
                    if (addWaypointRallyPointAction.checked) {
                    	insertSimpleItemAfterCurrent(coordinate)
                    } else if (_addROIOnClick) {
                    	insertROIAfterCurrent(coordinate)
                        _addROIOnClick = false
                    }
                    break
                }
            }

            // Add the mission item visuals to the map
            Repeater {
                model: _missionController.visualItems
                delegate: MissionItemMapVisual {
                    map:         editorMap
                    opacity:     _editingLayer == _layerMission || _editingLayer == _layerUTMSP ? 1 : editorMap._nonInteractiveOpacity
                    interactive: _editingLayer == _layerMission || _editingLayer == _layerUTMSP
                    vehicle:     _planMasterController.controllerVehicle
                    onClicked:   (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false) }
                }
            }

            // Add lines between waypoints
            MissionLineView {
                showSpecialVisual:  _missionController.isROIBeginCurrentItem
                model:              _missionController.simpleFlightPathSegments
                opacity:            _editingLayer == _layerMission ||  _editingLayer == _layerUTMSP  ? 1 : editorMap._nonInteractiveOpacity
            }

            // Direction arrows in waypoint lines
            MapItemView {
                model: _editingLayer == _layerMission ||_editingLayer == _layerUTMSP ? _missionController.directionArrows : undefined

                delegate: MapLineArrow {
                    fromCoord:      object ? object.coordinate1 : undefined
                    toCoord:        object ? object.coordinate2 : undefined
                    arrowPosition:  3
                    z:              QGroundControl.zOrderWaypointLines + 1
                }
            }

            // Incomplete segment lines
            MapItemView {
                model: _missionController.incompleteComplexItemLines

                delegate: MapPolyline {
                    path:       [ object.coordinate1, object.coordinate2 ]
                    line.width: 1
                    line.color: "red"
                    z:          QGroundControl.zOrderWaypointLines
                    opacity:    _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                }
            }

            // UI for splitting the current segment
            MapQuickItem {
                id:             splitSegmentItem
                anchorPoint.x:  sourceItem.width / 2
                anchorPoint.y:  sourceItem.height / 2
                z:              QGroundControl.zOrderWaypointLines + 1
                visible:        _editingLayer == _layerMission ||  _editingLayer == _layerUTMSP

                sourceItem: SplitIndicator {
                    onClicked:  _missionController.insertSimpleMissionItem(splitSegmentItem.coordinate,
                                                                           _missionController.currentPlanViewVIIndex,
                                                                           true /* makeCurrentItem */)
                }

                function _updateSplitCoord() {
                    if (_missionController.splitSegment) {
                        var distance = _missionController.splitSegment.coordinate1.distanceTo(_missionController.splitSegment.coordinate2)
                        var azimuth = _missionController.splitSegment.coordinate1.azimuthTo(_missionController.splitSegment.coordinate2)
                        splitSegmentItem.coordinate = _missionController.splitSegment.coordinate1.atDistanceAndAzimuth(distance / 2, azimuth)
                    } else {
                        coordinate = QtPositioning.coordinate()
                    }
                }

                Connections {
                    target:                 _missionController
                    function onSplitSegmentChanged()  { splitSegmentItem._updateSplitCoord() }
                }

                Connections {
                    target:                 _missionController.splitSegment
                    function onCoordinate1Changed()   { splitSegmentItem._updateSplitCoord() }
                    function onCoordinate2Changed()   { splitSegmentItem._updateSplitCoord() }
                }
            }

            // Add the vehicles to the map
            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle:        object
                    coordinate:     object.coordinate
                    map:            editorMap
                    size:           ScreenTools.defaultFontPixelHeight * 3
                    z:              QGroundControl.zOrderMapItems - 1
                }
            }

            GeoFenceMapVisuals {
                map:                    editorMap
                myGeoFenceController:   _geoFenceController
                interactive:            _editingLayer == _layerGeoFence
                homePosition:           _missionController.plannedHomePosition
                planView:               true
                opacity:                _editingLayer != _layerGeoFence ? editorMap._nonInteractiveOpacity : 1
            }

            RallyPointMapVisuals {
                map:                    editorMap
                myRallyPointController: _rallyPointController
                interactive:            _editingLayer == _layerRallyPoints
                planView:               true
                opacity:                _editingLayer != _layerRallyPoints ? editorMap._nonInteractiveOpacity : 1
            }

            UTMSPMapVisuals {
                id: utmspvisual
                enabled:                _utmspEnabled
                map:                    editorMap
                currentMissionItems:    _visualItems
                myGeoFenceController:   _geoFenceController
                interactive:            _editingLayer == _layerUTMSP
                homePosition:           _missionController.plannedHomePosition
                planView:               true
                opacity:                _editingLayer != _layerUTMSP ? editorMap._nonInteractiveOpacity : 1
                resetCheck:             _resetGeofencePolygon
            }

            Connections {
                target: utmspEditor
                function onResetGeofencePolygonTriggered() {
                    resetTimer.start()
                }
            }
            Timer {
                id: resetTimer
                interval: 2500
                running: false
                repeat: false
                onTriggered: {
                    _resetGeofencePolygon = true
                }
            }
        }

        //-----------------------------------------------------------
        // Left tool strip
        ToolStrip {
            id:                 toolStrip
            anchors.margins:    _toolsMargin
            anchors.left:       parent.left
            anchors.top:        parent.top
            color: "transparent"
            z:                  QGroundControl.zOrderWidgets
            maxHeight:          parent.height - toolStrip.y

            readonly property int fileButtonIndex:      0
            readonly property int takeoffButtonIndex:   1
            readonly property int waypointButtonIndex:  2
            readonly property int roiButtonIndex:       3
            readonly property int patternButtonIndex:   4
            readonly property int landButtonIndex:      5
            readonly property int centerButtonIndex:    6

            property bool _isRallyLayer:    _editingLayer == _layerRallyPoints
            property bool _isMissionLayer:  _editingLayer == _layerMission
            property bool _isUtmspLayer:     _editingLayer == _layerUTMSP

            ToolStripActionList {
                id: toolStripActionList
                model: [
                    ToolStripAction {
                        text:                   qsTr("任务")
                        enabled:                !_planMasterController.syncInProgress
                        visible:                true
                        showAlternateIcon:      _planMasterController.dirty
                        iconSource:             "/qmlimages/MapSync.svg"
                        alternateIconSource:    "/qmlimages/MapSyncChanged.svg"
                        dropPanelComponent:     syncDropPanel
                    },
                    ToolStripAction {
                        text:       qsTr("起飞")
                        iconSource: "/res/takeoff.svg"
                        enabled:    _missionController.isInsertTakeoffValid
                        visible:    (toolStrip._isMissionLayer || toolStrip._isUtmspLayer) && !_planMasterController.controllerVehicle.rover
                        onTriggered: {
                            toolStrip.allAddClickBoolsOff()
                            insertTakeItemAfterCurrent()
                            _triggerSubmit = true
                        }
                    },
                    ToolStripAction {
                        id:                 addWaypointRallyPointAction
                        text:               _editingLayer == _layerRallyPoints ? qsTr("集合点") : qsTr("航点")
                        iconSource:         "/qmlimages/MapAddMission.svg"
                        enabled:            toolStrip._isRallyLayer ? true : _missionController.flyThroughCommandsAllowed
                        visible:            toolStrip._isRallyLayer || toolStrip._isMissionLayer || toolStrip._isUtmspLayer
                        checkable:          true
                    },
                    // ToolStripAction {
                    //     text:               _missionController.isROIActive ? qsTr("取消ROI") : qsTr("ROI")
                    //     iconSource:         "/qmlimages/MapAddMission.svg"
                    //     enabled:            !_missionController.onlyInsertTakeoffValid
                    //     visible:            toolStrip._isMissionLayer && _planMasterController.controllerVehicle.roiModeSupported
                    //     checkable:          !_missionController.isROIActive
                    //     onCheckedChanged:   _addROIOnClick = checked
                    //     onTriggered: {
                    //         if (_missionController.isROIActive) {
                    //             toolStrip.allAddClickBoolsOff()
                    //             insertCancelROIAfterCurrent()
                    //         }
                    //     }
                    //     property bool myAddROIOnClick: _addROIOnClick
                    //     onMyAddROIOnClickChanged: checked = _addROIOnClick
                    // },
                    ToolStripAction {
                        text:               _singleComplexItem ? _missionController.complexMissionItemNames[0] : qsTr("模式")
                        iconSource:         "/qmlimages/MapDrawShape.svg"
                        enabled:            _missionController.flyThroughCommandsAllowed
                        visible:            toolStrip._isMissionLayer
                        dropPanelComponent: _singleComplexItem ? undefined : patternDropPanel
                        onTriggered: {
                            toolStrip.allAddClickBoolsOff()
                            if (_singleComplexItem) {
                                insertComplexItemAfterCurrent(_missionController.complexMissionItemNames[0])
                            }
                        }
                    },
                    ToolStripAction {
                        text:       _planMasterController.controllerVehicle.multiRotor
                                    ? qsTr("返航")
                                    : _missionController.isInsertLandValid && _missionController.hasLandItem
                                      ? qsTr("低悬降落")
                                      : qsTr("降落")
                        iconSource: "/res/rtl.svg"
                        enabled:    _missionController.isInsertLandValid
                        visible:    toolStrip._isMissionLayer || toolStrip._isUtmspLayer
                        onTriggered: {
                            toolStrip.allAddClickBoolsOff()
                            insertLandItemAfterCurrent()
                        }
                    },
                    ToolStripAction {
                        text:               qsTr("中心")
                        iconSource:         "/qmlimages/MapCenter.svg"
                        enabled:            true
                        visible:            true
                        dropPanelComponent: centerMapDropPanel
                    }
                ]
            }

            model: toolStripActionList.model

            function allAddClickBoolsOff() {
                _addROIOnClick =        false
                addWaypointRallyPointAction.checked = false
            }

            onDropped: allAddClickBoolsOff()
        }

        //-----------------------------------------------------------
        // Right pane for mission editing controls
        Rectangle {
            id:                 rightPanel
            height:             parent.height
            width:{
                 if(_utmspEnabled){
                     _rightPanelWidth + ScreenTools.defaultFontPixelWidth * 21.667
                 }
                 else{
                     _rightPanelWidth
                 }
             }
            // color:              qgcPal.window
            color: "transparent"
            opacity:            layerTabBar.visible ? 0.2 : 0
            anchors.bottom:     parent.bottom
            anchors.right:      parent.right
            anchors.rightMargin: _toolsMargin
        }
        //-------------------------------------------------------
        // Right Panel Controls
        Item {
            anchors.fill:           rightPanel
            anchors.topMargin:      _toolsMargin
            DeadMouseArea {
                anchors.fill:   parent
            }
            Column {
                id:                 rightControls
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        parent.top
                //-------------------------------------------------------
                // Mission Controls (Expanded)
                QGCTabBar {
                    id:         layerTabBar
                    width:      parent.width
                    visible:    QGroundControl.corePlugin.options.enablePlanViewSelector  && !_utmspEnabled
                    Component.onCompleted: currentIndex = 0
                    QGCTabButton {
                        text:       qsTr("任务")
                    }
                    QGCTabButton {
                        text:       qsTr("围栏")
                        enabled:    _geoFenceController.supported
                    }
                    QGCTabButton {
                        text:       qsTr("集合点")
                        enabled:    _rallyPointController.supported
                    }
                }

                QGCTabBar {
                    id:         layerTabBarUTMSP
                    width:      parent.width
                    visible:    QGroundControl.corePlugin.options.enablePlanViewSelector && _utmspEnabled
                    QGCTabButton {
                        text:       qsTr("任务")
                    }
                    QGCTabButton {
                        text:       qsTr("集合点")
                        enabled:    _rallyPointController.supported
                    }
                    QGCTabButton {
                        id: utmspbutton
                        text:       qsTr("UTM-适配器")
                        visible: _utmspEnabled
                    }
                }
            }
            //-------------------------------------------------------
            // Mission Item Editor
            Item {
                id:                     missionItemEditor
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            rightControls.bottom
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.25
                anchors.bottom:         parent.bottom
                anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.25
                visible:                _editingLayer == _layerMission && !planControlColapsed
                QGCListView {
                    id:                 missionItemEditorListView
                    anchors.fill:       parent
                    spacing:            ScreenTools.defaultFontPixelHeight / 4
                    orientation:        ListView.Vertical
                    model:              _missionController.visualItems
                    cacheBuffer:        Math.max(height * 2, 0)
                    clip:               true
                    currentIndex:       _missionController.currentPlanViewSeqNum
                    highlightMoveDuration: 250
                    visible:            _editingLayer == _layerMission && !planControlColapsed
                    //-- List Elements
                    delegate: MissionItemEditor {
                        map:            editorMap
                        masterController:  _planMasterController
                        missionItem:    object
                        width:          missionItemEditorListView.width
                        readOnly:       false
                        onClicked: (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(object.sequenceNumber, false) }
                        onRemove: {
                            var removeVIIndex = index
                            _missionController.removeVisualItem(removeVIIndex)
                            if (removeVIIndex >= _missionController.visualItems.count) {
                                removeVIIndex--
                            }
                        }
                        onSelectNextNotReadyItem:   selectNextNotReady()
                    }
                }
            }
            // GeoFence Editor
            GeoFenceEditor {
                anchors.top:            rightControls.bottom
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.25
                anchors.bottom:         parent.bottom
                anchors.left:           parent.left
                anchors.right:          parent.right
                myGeoFenceController:   _geoFenceController
                flightMap:              editorMap
                visible:                _editingLayer == _layerGeoFence
            }

            // Rally Point Editor
            RallyPointEditorHeader {
                id:                     rallyPointHeader
                anchors.top:            rightControls.bottom
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.25
                anchors.left:           parent.left
                anchors.right:          parent.right
                visible:                _editingLayer == _layerRallyPoints
                controller:             _rallyPointController
            }
            RallyPointItemEditor {
                id:                     rallyPointEditor
                anchors.top:            rallyPointHeader.bottom
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.25
                anchors.left:           parent.left
                anchors.right:          parent.right
                visible:                _editingLayer == _layerRallyPoints && _rallyPointController.points.count
                rallyPoint:             _rallyPointController.currentRallyPoint
                controller:             _rallyPointController
            }
            UTMSPAdapterEditor{
                id: utmspEditor
                enabled:                 _utmspEnabled
                anchors.top:             rightControls.bottom
                anchors.topMargin:       ScreenTools.defaultFontPixelHeight * 0.25
                anchors.bottom:          parent.bottom
                anchors.left:            parent.left
                anchors.right:           parent.right
                currentMissionItems:     _visualItems
                myGeoFenceController:    _geoFenceController
                flightMap:               editorMap
                visible:                 _editingLayer == _layerUTMSP
                triggerSubmitButton:     _triggerSubmit
                resetRegisterFlightPlan: _resetRegisterFlightPlan
            }
        }

        QGCLabel {
            // Elevation provider notice on top of terrain plot
            readonly property string _licenseString: QGroundControl.elevationProviderNotice

            id:                         licenseLabel
            visible:                    terrainStatus.visible && _licenseString !== ""
            anchors.bottom:             terrainStatus.top
            anchors.horizontalCenter:   terrainStatus.horizontalCenter
            anchors.bottomMargin:       ScreenTools.defaultFontPixelWidth * 0.5
            font.pointSize:             ScreenTools.smallFontPointSize
            text:                       qsTr("由 %1 提供").arg(_licenseString)
        }

        TerrainStatus {
            id:                 terrainStatus

            anchors.margins:    _toolsMargin
            anchors.leftMargin: 0
            anchors.left:       mapScale.left
            anchors.right:      rightPanel.left
            anchors.bottom:     parent.bottom
            height:             ScreenTools.defaultFontPixelHeight * 7
            missionController:  _missionController
            // visible:            _internalVisible && _editingLayer === _layerMission && QGroundControl.corePlugin.options.showMissionStatus
            visible:false

            onSetCurrentSeqNum: _missionController.setCurrentPlanViewSeqNum(seqNum, true)

            property bool _internalVisible: _planViewSettings.showMissionItemStatus.rawValue

            function toggleVisible() {
                _internalVisible = !_internalVisible
                _planViewSettings.showMissionItemStatus.rawValue = _internalVisible
            }
        }

        MapScale {
            id:                     mapScale
            anchors.margins:        _toolsMargin
            anchors.bottom:         terrainStatus.visible ? terrainStatus.top : parent.bottom
            anchors.left:           toolStrip.y + toolStrip.height + _toolsMargin > mapScale.y ? toolStrip.right: parent.left
            mapControl:             editorMap
            buttonsOnLeft:          true
            terrainButtonVisible:   _editingLayer === _layerMission
            terrainButtonChecked:   terrainStatus.visible
            onTerrainButtonClicked: terrainStatus.toggleVisible()
        }
    }

    function showLoadFromFileOverwritePrompt(title) {
        mainWindow.showMessageDialog(title,
                                     qsTr("您有未保存/未发送的更改。从文件加载将丢失这些更改。您确定要从文件加载吗？"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() { _planMasterController.loadFromSelectedFile() } )
    }

    Component {
        id: createPlanRemoveAllPromptDialog

        QGCSimpleMessageDialog {
            title:      qsTr("创建计划")
            text:       qsTr("您确定要删除当前计划并创建新计划吗？")
            buttons:    Dialog.Yes | Dialog.No

            property var mapCenter
            property var planCreator

            onAccepted: planCreator.createPlan(mapCenter)
        }
    }

    function clearButtonClicked() {
        mainWindow.showMessageDialog(qsTr("清除"),
                                     qsTr("您确定要删除所有任务项并清除设备的任务吗？"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() { _planMasterController.removeAllFromVehicle();
                                                  _missionController.setCurrentPlanViewSeqNum(0, true);
                                                  if(_utmspEnabled)
                                                    {_resetRegisterFlightPlan = true;
                                                      QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(false);
                                                      UTMSPStateStorage.startTimeStamp = "";
                                                      UTMSPStateStorage.showActivationTab = false;
                                                      UTMSPStateStorage.flightID = "";
                                                      UTMSPStateStorage.enableMissionUploadButton = false;
                                                      UTMSPStateStorage.indicatorPendingStatus = true;
                                                      UTMSPStateStorage.indicatorApprovedStatus = false;
                                                      UTMSPStateStorage.indicatorActivatedStatus = false;
                                                      UTMSPStateStorage.currentStateIndex = 0}})
    }

    //- ToolStrip ToolStripDropPanel Components

    Component {
        id: centerMapDropPanel

        CenterMapDropPanel {
            map:            editorMap
            fitFunctions:   mapFitFunctions
        }
    }

    Component {
        id: patternDropPanel

        ColumnLayout {
            spacing:    ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel { text: qsTr("创建复杂模式:") }

            Repeater {
                model: _missionController.complexMissionItemNames

                QGCButton {
                    text:               modelData
                    Layout.fillWidth:   true

                    onClicked: {
                        insertComplexItemAfterCurrent(modelData)
                        dropPanel.hide()
                    }
                }
            }
        } // Column
    }

    function downloadClicked(title) {
        if (_planMasterController.dirty) {
            mainWindow.showMessageDialog(title,
                                         qsTr("您有未保存/未发送的更改。从设备加载将丢失这些更改。您确定要从设备加载吗？"),
                                         Dialog.Yes | Dialog.Cancel,
                                         function() { _planMasterController.loadFromVehicle() })
        } else {
            _planMasterController.loadFromVehicle()
        }
    }

    Component {
        id: syncDropPanel

        ColumnLayout {
            id:         columnHolder
            spacing:    _margin

            property string _overwriteText: qsTr("计划重写")

            QGCLabel {
                id:                 unsavedChangedLabel
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                text:               globals.activeVehicle ?
                                        qsTr("您有未保存的更改。您应该上传到您的设备，或保存到文件。") :
                                        qsTr("您有未保存的更改。")
                visible:            _planMasterController.dirty
            }

            SectionHeader {
                id:                 createSection
                Layout.fillWidth:   true
                text:               qsTr("创建计划")
                showSpacer:         false
            }

            GridLayout {
                columns:            2
                columnSpacing:      _margin
                rowSpacing:         _margin
                Layout.fillWidth:   true
                visible:            createSection.checked

                Repeater {
                    model: _planMasterController.planCreators

                    Rectangle {
                        id:     button
                        width:  ScreenTools.defaultFontPixelHeight * 7
                        height: planCreatorNameLabel.y + planCreatorNameLabel.height
                        color:  button.pressed || button.highlighted ? qgcPal.buttonHighlight : qgcPal.button

                        property bool highlighted: mouseArea.containsMouse
                        property bool pressed:     mouseArea.pressed

                        Image {
                            id:                 planCreatorImage
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            source:             object.imageResource
                            sourceSize.width:   width
                            fillMode:           Image.PreserveAspectFit
                            mipmap:             true
                        }

                        QGCLabel {
                            id:                     planCreatorNameLabel
                            anchors.top:            planCreatorImage.bottom
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            horizontalAlignment:    Text.AlignHCenter
                            text:                   object.name

                            color:                  button.pressed || button.highlighted ? qgcPal.buttonHighlightText : qgcPal.buttonText
                        }

                        QGCMouseArea {
                            id:                 mouseArea
                            anchors.fill:       parent
                            hoverEnabled:       true
                            preventStealing:    true
                            onClicked:          {
                                if (_planMasterController.containsItems) {
                                    createPlanRemoveAllPromptDialog.createObject(mainWindow, { mapCenter: _mapCenter(), planCreator: object }).open()
                                } else {
                                    object.createPlan(_mapCenter())
                                }
                                dropPanel.hide()
                            }

                            function _mapCenter() {
                                var centerPoint = Qt.point(editorMap.centerViewport.left + (editorMap.centerViewport.width / 2), editorMap.centerViewport.top + (editorMap.centerViewport.height / 2))
                                return editorMap.toCoordinate(centerPoint, false /* clipToViewPort */)
                            }
                        }
                    }
                }
            }

            SectionHeader {
                id:                 storageSection
                Layout.fillWidth:   true
                text:               qsTr("存储")
            }

            GridLayout {
                columns:            3
                rowSpacing:         _margin
                columnSpacing:      ScreenTools.defaultFontPixelWidth
                visible:            storageSection.checked

                QGCButton {
                    text:               qsTr("打开...")
                    Layout.fillWidth:   true
                    enabled:            !_planMasterController.syncInProgress
                    onClicked: {
                        dropPanel.hide()
                        if (_planMasterController.dirty) {
                            showLoadFromFileOverwritePrompt(columnHolder._overwriteText)
                        } else {
                            _planMasterController.loadFromSelectedFile()
                        }
                    }
                }

                QGCButton {
                    text:               qsTr("保存")
                    Layout.fillWidth:   true
                    enabled:            !_planMasterController.syncInProgress && _planMasterController.currentPlanFile !== ""
                    onClicked: {
                        dropPanel.hide()
                        if(_planMasterController.currentPlanFile !== "") {
                            _planMasterController.saveToCurrent()
                        } else {
                            _planMasterController.saveToSelectedFile()
                        }
                    }
                }

                QGCButton {
                    text:               qsTr("另存为...")
                    Layout.fillWidth:   true
                    enabled:            !_planMasterController.syncInProgress && _planMasterController.containsItems
                    onClicked: {
                        dropPanel.hide()
                        _planMasterController.saveToSelectedFile()
                    }
                }

                QGCButton {
                    Layout.columnSpan:  3
                    Layout.fillWidth:   true
                    text:               qsTr("保存任务点为KML...")
                    enabled:            !_planMasterController.syncInProgress && _visualItems.count > 1
                    onClicked: {
                        // First point does not count
                        if (_visualItems.count < 2) {
                            mainWindow.showMessageDialog(qsTr("KML"), qsTr("您需要至少一个项目才能创建KML。"))
                            return
                        }
                        dropPanel.hide()
                        _planMasterController.saveKmlToSelectedFile()
                    }
                }
            }

            SectionHeader {
                id:                 vehicleSection
                Layout.fillWidth:   true
                text:               qsTr("设备")
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            vehicleSection.checked

                QGCButton {
                    text:               qsTr("上传")
                    Layout.fillWidth:   true
                    enabled:            !_planMasterController.offline && !_planMasterController.syncInProgress && _planMasterController.containsItems
                    visible:            !QGroundControl.corePlugin.options.disableVehicleConnection
                    onClicked: {
                        dropPanel.hide()
                        _planMasterController.upload()
                    }
                }

                QGCButton {
                    text:               qsTr("下载")
                    Layout.fillWidth:   true
                    enabled:            !_planMasterController.offline && !_planMasterController.syncInProgress
                    visible:            !QGroundControl.corePlugin.options.disableVehicleConnection

                    onClicked: {
                        dropPanel.hide()
                        downloadClicked(columnHolder._overwriteText)
                    }
                }

                QGCButton {
                    text:               qsTr("清除")
                    Layout.fillWidth:   true
                    Layout.columnSpan:  2
                    enabled:            !_planMasterController.offline && !_planMasterController.syncInProgress
                    visible:            !QGroundControl.corePlugin.options.disableVehicleConnection
                    onClicked: {
                        dropPanel.hide()
                        clearButtonClicked()
                    }
                }
            }
        }
    }

    Connections {
        target: utmspEditor
        function onVehicleIDSent(id) {
            _vehicleID = id
        }
    }
    Connections {
        target: utmspEditor
        function onRemoveFlightPlanTriggered() {
            _planMasterController.removeAllFromVehicle();
            _missionController.setCurrentPlanViewSeqNum(0, true);
            if(_utmspEnabled){_resetRegisterFlightPlan = true}
        }
    }
}
