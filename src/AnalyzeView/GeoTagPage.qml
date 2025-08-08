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
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Controllers

AnalyzePage {
    pageComponent: pageComponent
    pageDescription: qsTr("用于标记一组来自勘测任务的图像，并附带 GPS 坐标。您必须提供飞行中的二进制日志以及包含待标记图像的目录。")

    readonly property real _margin: ScreenTools.defaultFontPixelWidth * 2
    readonly property real _minWidth: ScreenTools.defaultFontPixelWidth * 20
    readonly property real _maxWidth: ScreenTools.defaultFontPixelWidth * 30

    Component {
        id: pageComponent

        GridLayout {
            columns: 2
            columnSpacing: _margin
            rowSpacing: ScreenTools.defaultFontPixelWidth * 2
            width: availableWidth

            BusyIndicator {
                running: (geoController.progress > 0) && (geoController.progress < 100) && !geoController.errorMessage
                width: progressBar.height
                height: progressBar.height
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            }

            ProgressBar {
                id: progressBar
                to: 100
                value: geoController.progress
                opacity: (geoController.progress > 0) ? 1 : 0.25
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            QGCLabel {
                text: geoController.errorMessage
                color: "red"
                font.bold: true
                font.pointSize: ScreenTools.mediumFontPointSize
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                Layout.columnSpan: 2
            }

            QGCButton {
                text: qsTr("选择日志文件")
                Layout.minimumWidth: _minWidth
                Layout.maximumWidth: _maxWidth
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                onClicked: openLogFile.openForLoad()

                QGCFileDialog {
                    id: openLogFile
                    title: qsTr("选择日志文件")
                    nameFilters: [qsTr("ULog 日志文件 (*.ulg)"), qsTr("PX4 日志文件 (*.px4log)"), qsTr("所有文件 (*)")]
                    defaultSuffix: "ulg"
                    onAcceptedForLoad: (file) => {
                        geoController.logFile = file
                        close()
                    }
                }
            }

            QGCLabel {
                text: geoController.logFile
                elide: Text.ElideLeft
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            QGCButton {
                text: qsTr("选择图像目录")
                Layout.minimumWidth: _minWidth
                Layout.maximumWidth: _maxWidth
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                onClicked: selectImageDir.openForLoad()

                QGCFileDialog {
                    id: selectImageDir
                    title: qsTr("选择图像目录")
                    selectFolder: true
                    onAcceptedForLoad: (file) => {
                        geoController.imageDirectory = file
                        close()
                    }
                }
            }

            QGCLabel {
                text: geoController.imageDirectory
                elide: Text.ElideLeft
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            QGCButton {
                text: qsTr("(可选) 选择保存目录")
                Layout.minimumWidth: _minWidth
                Layout.maximumWidth: _maxWidth
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                onClicked: selectDestDir.openForLoad()

                QGCFileDialog {
                    id: selectDestDir
                    title: qsTr("选择保存目录")
                    selectFolder: true
                    onAcceptedForLoad: (file) => {
                        geoController.saveDirectory = file
                        close()
                    }
                }
            }

            QGCLabel {
                text: {
                    if (geoController.saveDirectory) {
                        return geoController.saveDirectory;
                    } else if (geoController.imageDirectory) {
                        return geoController.imageDirectory + qsTr("/标记后的图像");
                    } else {
                        return qsTr("/标记后的图像文件夹在您的图像文件夹中");
                    }
                }
                elide: Text.ElideLeft
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            QGCButton {
                text: geoController.inProgress ? qsTr("取消标记") : qsTr("开始标记")
                enabled: (geoController.imageDirectory && geoController.logFile) || geoController.inProgress
                Layout.minimumWidth: _minWidth
                Layout.maximumWidth: _maxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.columnSpan: 2
                onClicked: {
                    if (geoController.inProgress) {
                        geoController.cancelTagging()
                    } else {
                        geoController.startTagging()
                    }
                }
            }
        }
    }
}
