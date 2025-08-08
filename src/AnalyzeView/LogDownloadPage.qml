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
import Qt.labs.qmlmodels

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.ScreenTools

AnalyzePage {
    id: logDownloadPage
    pageComponent: pageComponent
    pageDescription: qsTr("日志下载允许您从您的设备中下载二进制日志文件。点击刷新以获取可用日志的列表。")

    Component {
        id: pageComponent

        RowLayout {
            width: availableWidth
            height: availableHeight

            QGCFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: gridLayout.width
                contentHeight: gridLayout.height

                GridLayout {
                    id: gridLayout
                    rows: logDownloadController.model.count + 1
                    columns: 5
                    flow: GridLayout.TopToBottom
                    columnSpacing: ScreenTools.defaultFontPixelWidth
                    rowSpacing: 0

                    QGCCheckBox {
                        id: headerCheckBox
                        enabled: false
                    }

                    Repeater {
                        model: logDownloadController.model

                        QGCCheckBox {
                            Binding on checkState {
                                value: object.selected ? Qt.Checked : Qt.Unchecked
                            }

                            onClicked: object.selected = checked
                        }
                    }

                    QGCLabel { text: qsTr("Id") }

                    Repeater {
                        model: logDownloadController.model

                        QGCLabel { text: object.id }
                    }

                    QGCLabel { text: qsTr("日期") }

                    Repeater {
                        model: logDownloadController.model

                        QGCLabel {
                            text: {
                                if (!object.received) {
                                    return ""
                                }

                                if (object.time.getUTCFullYear() < 2010) {
                                    return qsTr("未知日期")
                                }

                                return object.time.toLocaleString(undefined)
                            }
                        }
                    }

                    QGCLabel { text: qsTr("尺寸") }

                    Repeater {
                        model: logDownloadController.model

                        QGCLabel { text: object.sizeStr }
                    }

                    QGCLabel { text: qsTr("状态") }

                    Repeater {
                        model: logDownloadController.model

                        QGCLabel { text: object.status }
                    }
                }
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !logDownloadController.requestingList && !logDownloadController.downloadingLogs
                    text: qsTr("刷新")

                    onClicked: {
                        if (!QGroundControl.multiVehicleManager.activeVehicle || QGroundControl.multiVehicleManager.activeVehicle.isOfflineEditingVehicle) {
                            mainWindow.showMessageDialog(qsTr("日志刷新"), qsTr("您必须连接到设备才能下载日志。"))
                            return
                        }

                        logDownloadController.refresh()
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !logDownloadController.requestingList && !logDownloadController.downloadingLogs
                    text: qsTr("下载")

                    onClicked: {
                        var logsSelected = false
                        for (var i = 0; i < logDownloadController.model.count; i++) {
                            if (logDownloadController.model.get(i).selected) {
                                logsSelected = true
                                break
                            }
                        }

                        if (!logsSelected) {
                            mainWindow.showMessageDialog(qsTr("日志下载"), qsTr("您必须选择至少一个日志文件才能下载。"))
                            return
                        }

                        if (ScreenTools.isMobile) {
                            logDownloadController.download()
                            return
                        }

                        fileDialog.title = qsTr("选择保存目录")
                        fileDialog.folder = QGroundControl.settingsManager.appSettings.logSavePath
                        fileDialog.selectFolder = true
                        fileDialog.openForLoad()
                    }

                    QGCFileDialog {
                        id: fileDialog
                        onAcceptedForLoad: (file) => {
                            logDownloadController.download(file)
                            close()
                        }
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !logDownloadController.requestingList && !logDownloadController.downloadingLogs && (logDownloadController.model.count > 0)
                    text: qsTr("删除所有")
                    onClicked: mainWindow.showMessageDialog(
                        qsTr("删除所有日志文件"),
                        qsTr("所有日志文件将被永久删除。是否确定？"),
                        Dialog.Yes | Dialog.No,
                        function() { logDownloadController.eraseAll() }
                    )
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: qsTr("取消下载")
                    enabled: logDownloadController.requestingList || logDownloadController.downloadingLogs
                    onClicked: logDownloadController.cancel()
                }
            }
        }
    }
}
