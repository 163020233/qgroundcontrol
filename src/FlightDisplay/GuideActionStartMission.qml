import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.Controllers

GuidedToolStripAction {
    text:       "操作"
    iconSource: "qrc:/qmlimages/HamburgerThin.svg"
    visible: true
    enabled: true
    actionID:   _guidedController.actionStartMission
}





