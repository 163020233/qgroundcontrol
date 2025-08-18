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
    title:      qsTr("RC 通道到参数")
    buttons:    Dialog.Cancel | Dialog.Ok

    property alias tuningFact: controller.tuningFact

    onAccepted: QGroundControl.multiVehicleManager.activeVehicle.sendParamMapRC(tuningFact.name, scale.text, centerValue.text, tuningID.currentIndex, minValue.text, maxValue.text)

    RCToParamDialogController {
        id: controller
    }

    ColumnLayout {
        spacing: ScreenTools.defaultDialogControlSpacing

        QGCLabel {
            Layout.preferredWidth:  mainGrid.width
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            text:                   qsTr("将 RC 频道绑定到参数值。可以从“无线电设置”页面将调谐 ID 映射到 RC 频道。")
        }

        QGCLabel {
            Layout.preferredWidth:  mainGrid.width
            Layout.fillWidth:       true
            text:                   qsTr("等待设备更新参数。")
            visible:                !controller.ready
        }

        GridLayout {
            id:             mainGrid
            columns:        2
            rowSpacing:     ScreenTools.defaultDialogControlSpacing
            columnSpacing:  ScreenTools.defaultDialogControlSpacing
            enabled:        controller.ready

            QGCLabel { text: qsTr("参数") }
            QGCLabel { text: tuningFact.name }

            QGCLabel { text: qsTr("调谐 ID") }
            QGCComboBox {
                id:                 tuningID
                Layout.fillWidth:   true
                currentIndex:       0
                model:              [ 1, 2, 3 ]
            }

            QGCLabel { text: qsTr("缩放") }
            QGCTextField {
                id:     scale
                text:   controller.scale.valueString
            }

            QGCLabel { text: qsTr("中心值") }
            QGCTextField {
                id:     centerValue
                text:   controller.center.valueString
            }

            QGCLabel { text: qsTr("最小值") }
            QGCTextField {
                id:     minValue
                text:   controller.min.valueString
            }

            QGCLabel { text: qsTr("最大值") }
            QGCTextField {
                id:     maxValue
                text:   controller.max.valueString
            }
        }

        QGCLabel {
            Layout.preferredWidth:  mainGrid.width
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            text:                   qsTr("请在确认对话框之前检查所有值是否正确。")
        }
    }
}
