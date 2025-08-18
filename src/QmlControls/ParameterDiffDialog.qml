/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controllers

QGCPopupDialog {
    title:      qsTr("加载参数")
    buttons:    Dialog.Cancel | (paramController.diffList.count ? Dialog.Ok : 0)

    property var paramController

    onAccepted: paramController.sendDiff()

    Component.onDestruction: paramController.clearDiff();

    ColumnLayout {
        spacing: ScreenTools.defaultDialogControlSpacing

        QGCLabel {
            Layout.preferredWidth:  mainGrid.visible ? mainGrid.width : ScreenTools.defaultFontPixelWidth * 40
            wrapMode:               Text.WordWrap
            text:                   paramController.diffList.count ?
                                        qsTr("以下参数从加载的文件与当前设备设置不同。 点击“确定”将它们更新到设备上。") :
                                        qsTr("加载的文件与当前设备设置没有差异。")
        }

        GridLayout {
            id:         mainGrid
            rows:       paramController.diffList.count + 1
            columns:    paramController.diffMultipleComponents ? 5 : 4
            flow:       GridLayout.TopToBottom
            visible:    paramController.diffList.count

            QGCCheckBox {
                checked: true
                onClicked: {
                    for (var i=0; i<paramController.diffList.count; i++) {
                        paramController.diffList.get(i).load = checked
                    }
                }
            }
            Repeater {
                model: paramController.diffList
                QGCCheckBox {
                    checked:    object.load
                    onClicked:  object.load = checked
                }
            }

            Repeater {
                model: paramController.diffMultipleComponents ? 1 : 0
                QGCLabel { text: qsTr("组件 ID") }
            }
            Repeater {
                model: paramController.diffMultipleComponents ? paramController.diffList : 0
                QGCLabel { text: object.componentId }
            }

            QGCLabel { text: qsTr("名称") }
            Repeater {
                model: paramController.diffList
                QGCLabel { text: object.name }
            }

            QGCLabel { text: qsTr("文件") }
            Repeater {
                model: paramController.diffList
                QGCLabel { text: object.fileValue + " " + object.units }
            }

            QGCLabel { text: qsTr("设备") }
            Repeater {
                model: paramController.diffList
                QGCLabel { text: object.noVehicleValue ? qsTr("N/A") : object.vehicleValue + " " + object.units }
            }
        }
    }
}
