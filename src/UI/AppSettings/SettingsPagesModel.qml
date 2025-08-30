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
import QGroundControl.ScreenTools

ListModel {
    ListElement {
        name: qsTr("通用")
        url: "qrc:/qml/QGroundControl/AppSettings/GeneralSettings.qml"
        iconUrl: "qrc:/res/gear-white.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("飞行视图")
        url: "qrc:/qml/QGroundControl/AppSettings/FlyViewSettings.qml"
        iconUrl: "qrc:/qmlimages/PaperPlane.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("计划视图")
        url: "qrc:/qml/QGroundControl/AppSettings/PlanViewSettings.qml"
        iconUrl: "qrc:/qmlimages/Plan.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("视频")
        url: "qrc:/qml/QGroundControl/AppSettings/VideoSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/camera.svg"
        pageVisible: function() { return QGroundControl.settingsManager.videoSettings.visible }
    }
    // ListElement {
    //     name: qsTr("Telemetry")
    //     url: "qrc:/qml/QGroundControl/AppSettings/TelemetrySettings.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/drone.svg"
    //     pageVisible: function() { return true }
    // }

    // ListElement {
    //     name: qsTr("ADSB Server")
    //     url: "qrc:/qml/QGroundControl/AppSettings/ADSBServerSettings.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/airplane.svg"
    //     pageVisible: function() { return true }
    // }

    ListElement {
        name: qsTr("通信链接")
        url: "qrc:/qml/QGroundControl/AppSettings/LinkSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/usb.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("地图")
        url: "qrc:/qml/QGroundControl/AppSettings/MapSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/globe.svg"
        pageVisible: function() { return true }
    }

    // ListElement {
    //     name: qsTr("PX4 Log Transfer")
    //     url: "qrc:/qml/QGroundControl/AppSettings/PX4LogTransferSettings.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/inbox-download.svg"
    //     pageVisible: function() {
    //         var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
    //         return QGroundControl.corePlugin.options.showPX4LogTransferOptions &&
    //                     QGroundControl.px4ProFirmwareSupported &&
    //                     (activeVehicle ? activeVehicle.px4Firmware : true)
    //     }
    // }

    // ListElement {
    //     name: qsTr("Remote ID")
    //     url: "qrc:/qml/QGroundControl/AppSettings/RemoteIDSettings.qml"
    //     iconUrl: "qrc:/qmlimages/RidIconManNoID.svg"
    //     pageVisible: function() { return true }
    // }

    // ListElement {
    //     name: qsTr("Console")
    //     url: "qrc:/qml/QGroundControl/Controls/AppMessages.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/conversation.svg"
    //     pageVisible: function() { return true }
    // }

    // ListElement {
    //     name: qsTr("Help")
    //     url: "qrc:/qml/QGroundControl/AppSettings/HelpSettings.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/question.svg"
    //     pageVisible: function() { return true }
    // }

    ListElement {
        name: qsTr("模拟链接")
        url: "qrc:/qml/QGroundControl/AppSettings/MockLink.qml"
        iconUrl: "qrc:/InstrumentValueIcons/drone.svg"
        pageVisible: function() { return ScreenTools.isDebug }
    }

    // ListElement {
    //     name: qsTr("Debug")
    //     url: "qrc:/qml/QGroundControl/AppSettings/DebugWindow.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/bug.svg"
    //     pageVisible: function() { return ScreenTools.isDebug }
    // }

    // ListElement {
    //     name: qsTr("Palette Test")
    //     url: "qrc:/qml/QGroundControl/AppSettings/QmlTest.qml"
    //     iconUrl: "qrc:/InstrumentValueIcons/photo.svg"
    //     pageVisible: function() { return ScreenTools.isDebug }
    // }
}

