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
import QGroundControl.FlightDisplay

ToolStrip {
    id: _root
    color: Qt.rgba(0, 0, 0, 0)
    signal displayPreFlightChecklist

    FlyViewToolStripActionList {
        id: flyViewToolStripActionList

        onDisplayPreFlightChecklist: _root.displayPreFlightChecklist()
    }

    model: flyViewToolStripActionList.model
}
