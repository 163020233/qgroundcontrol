import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Palette
import QGroundControl.ScreenTools

Rectangle {
    height: visible ? (rowLayout.height + (_margins * 2)) : 0
    color: qgcPal.window

    property real _margins: ScreenTools.defaultFontPixelHeight / 4
    property var _logReplayLink: null

    function pickLogFile() {
        if (globals.activeVehicle) {
            mainWindow.showMessageDialog(qsTr("日志重播"), qsTr("重播日志之前必须关闭所有连接。"))
            return
        }

        filePicker.openForLoad()
    }

    QGCPalette { id: qgcPal }

    QGCFileDialog {
        id: filePicker
        title: qsTr("选择日志文件")
        nameFilters: [ qsTr("日志文件 (*.%1)").arg(_logFileExtension), qsTr("所有文件 (*)") ]
        folder: QGroundControl.settingsManager.appSettings.telemetrySavePath
        onAcceptedForLoad: (file) => {
            controller.link = QGroundControl.linkManager.startLogReplay(file)
            close()
        }

        property string _logFileExtension: QGroundControl.settingsManager.appSettings.telemetryFileExtension
    }

    LogReplayLinkController {
        id: controller

        onPercentCompleteChanged: (percentComplete) => slider.updatePercentComplete(percentComplete)
    }

    RowLayout {
        id: rowLayout
        anchors {
            margins: _margins
            top: parent.top
            left: parent.left
            right: parent.right
        }

        QGCButton {
            enabled: controller.link
            text: controller.isPlaying ? qsTr("暂停") : qsTr("播放")
            onClicked: controller.isPlaying = !controller.isPlaying
        }

        QGCComboBox {
            textRole: "text"
            currentIndex: 3

            model: ListModel {
                ListElement { text: "0.1";  value: 0.1 }
                ListElement { text: "0.25"; value: 0.25 }
                ListElement { text: "0.5";  value: 0.5 }
                ListElement { text: "1x";   value: 1 }
                ListElement { text: "2x";   value: 2 }
                ListElement { text: "5x";   value: 5 }
                ListElement { text: "10x";  value: 10 }
            }

            onActivated: (index) => { controller.playbackSpeed = model.get(currentIndex).value }
        }

        QGCLabel { text: controller.playheadTime }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 100
            enabled: controller.link

            property bool manualUpdate: false

            function updatePercentComplete(percentComplete) {
                manualUpdate = true
                value = percentComplete
                manualUpdate = false
            }

            onValueChanged: {
                if (!manualUpdate) {
                    controller.percentComplete = value
                }
            }
        }

        QGCLabel { text: controller.totalTime }

        QGCButton {
            text: qsTr("加载日志文件")
            onClicked: pickLogFile()
            visible: !controller.link
        }

        QGCButton {
            text: qsTr("关闭")
            onClicked: {
                var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                if (activeVehicle) {
                    activeVehicle.closeVehicle()
                }
                QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue = false
            }
        }
    }
}
