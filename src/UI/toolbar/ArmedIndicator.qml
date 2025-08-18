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
import QGroundControl.Controls
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette

//-------------------------------------------------------------------------
//-- Armed Indicator
QGCComboBox {
    anchors.verticalCenter: parent.verticalCenter
    alternateText:          _armed ? qsTr("已解锁") : qsTr("已上锁")
    model:                  [ qsTr("解锁"), qsTr("上锁") ]
    font.pointSize:         ScreenTools.mediumFontPointSize
    currentIndex:           -1
    sizeToContents:         true

    property bool showIndicator: true

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _armed:         _activeVehicle ? _activeVehicle.armed : false

    onActivated: (index) => {
        if (index == 0) {
            mainWindow.armVehicleRequest()
        } else {
            mainWindow.disarmVehicleRequest()
        }
        currentIndex = -1
    }
}
