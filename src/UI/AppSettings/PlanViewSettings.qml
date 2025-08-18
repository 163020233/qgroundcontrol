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

import QGroundControl
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls

SettingsPage {
    property var _settingsManager:  QGroundControl.settingsManager
    property var _planViewSettings: QGroundControl.settingsManager.planViewSettings

    SettingsGroupLayout {
        Layout.fillWidth: true

        LabelledFactTextField {
            Layout.fillWidth:   true
            label:              qsTr("默认任务高度")
            fact:               _settingsManager.appSettings.defaultMissionItemAltitude
            visible:            fact.visible
        }

        LabelledFactTextField {
            Layout.fillWidth:   true
            label:              qsTr("VTOL 转换距离")
            fact:               _planViewSettings.vtolTransitionDistance
            visible:            fact.visible
        }

        FactCheckBoxSlider {
            Layout.fillWidth:   true
            text:               qsTr("使用 MAV_CMD_CONDITION_GATE 生成模式")
            fact:               _planViewSettings.useConditionGate
            visible:            fact.visible
        }

        FactCheckBoxSlider {
            Layout.fillWidth:   true
            text:               qsTr("任务不需要起飞项")
            fact:               _planViewSettings.takeoffItemNotRequired
            visible:            fact.visible
        }

        FactCheckBoxSlider {
            Layout.fillWidth:   true
            text:               qsTr("允许配置多个降落序列")
            fact:               _planViewSettings.allowMultipleLandingPatterns
            visible:            fact.visible
        }
    }
}
