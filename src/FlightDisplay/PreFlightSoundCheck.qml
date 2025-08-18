/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls

PreFlightCheckButton {
    name:                   qsTr("声音输出")
    manualText:             qsTr("QGC 音频输出已启用。系统音频输出也已启用吗？")
    telemetryTextFailure:   qsTr("QGC 音频输出已禁用。请在应用程序设置->常规下启用它以听到音频警告！")
    telemetryFailure:       QGroundControl.settingsManager.appSettings.audioMuted.rawValue
}
