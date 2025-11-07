/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQml.Models

import QGroundControl
import QGroundControl.Controls

ToolStripActionList {
    id: _root

    signal displayPreFlightChecklist

    model: [
        ToolStripAction {
            property bool _is3DViewOpen:            viewer3DWindow.isOpen
            property bool   _viewer3DEnabled:       QGroundControl.settingsManager.viewer3DSettings.enabled.rawValue

            id: view3DIcon
            visible: _viewer3DEnabled
            text:           qsTr("3D 视图")
            iconSource:     "/qmlimages/Viewer3D/City3DMapIcon.svg"
            onTriggered:{
                if(_is3DViewOpen === false){
                    viewer3DWindow.open()
                }else{
                    viewer3DWindow.close()
                }
            }

            on_Is3DViewOpenChanged: {
                if(_is3DViewOpen === true){
                    view3DIcon.iconSource =     "/qmlimages/PaperPlane.svg"
                    text=           qsTr("飞控")
                }else{
                    iconSource =     "/qmlimages/Viewer3D/City3DMapIcon.svg"
                    text =           qsTr("3D 视图")
                }
            }
        },
        PreFlightCheckListShowAction { onTriggered: displayPreFlightChecklist() },
        GuidedActionTakeoff { },
        GuideUnlock { },
        GuideLock {},
        // GuidedsetHomeTitle{ },
        GuidedActionLand { },
        GuidedActionRTL { },
        GuidedActionPause { },
        FlyViewAdditionalActionsButton { },
        // GuidedCenterMapButton {},
        GuidedActionGripper { },
        GuideActionStartMission { },
        ToolStripAction {
            id: planViewAction
            //text: qsTr("计划航线")
            text:       qsTr("任务")
            iconSource: "/qmlimages/Plan.svg"

            onTriggered: {
                if (mainWindow.allowViewSwitch()) {
                    mainWindow.closeIndicatorDrawer()
                    mainWindow.showPlanView()
                }
            }
        },
        ToolStripAction {
            id: settingsAction
            // text: qsTr("系统设置")
            text:       qsTr("设置")
            iconSource: "/res/gear-black.svg"
            visible: !QGroundControl.corePlugin.options.combineSettingsAndSetup

            onTriggered: {
                console.log("系统设置按钮被触发")
                if(mainWindow.allowViewSwitch()) {
                    mainWindow.closeIndicatorDrawer()   // <-- 关闭工具选择抽屉
                    mainWindow.showSettingsTool()
                }
            }
        }
    ]
}
