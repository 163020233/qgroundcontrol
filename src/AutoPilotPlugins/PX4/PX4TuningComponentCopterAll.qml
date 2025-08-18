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
import QGroundControl.FactSystem
import QGroundControl.ScreenTools

PX4TuningComponent {
    model: ListModel {
        ListElement { 
            buttonText: qsTr("速率控制器")
            tuningPage: "PX4TuningComponentCopterRate.qml"
        }
        ListElement { 
            buttonText: qsTr("姿态控制器")
            tuningPage: "PX4TuningComponentCopterAttitude.qml"
        }
        ListElement { 
            buttonText: qsTr("速度控制器")
            tuningPage: "PX4TuningComponentCopterVelocity.qml"
        }
        ListElement { 
            buttonText: qsTr("位置控制器")
            tuningPage: "PX4TuningComponentCopterPosition.qml"
        }
    }
}
