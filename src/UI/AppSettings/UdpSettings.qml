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
import QGroundControl.ScreenTools
import QGroundControl.Palette

ColumnLayout {
    spacing: _rowSpacing

    function saveSettings() {
        // No need
    }

    QGCLabel {
        Layout.preferredWidth: _secondColumnWidth
        Layout.fillWidth:       true
        font.pointSize:         ScreenTools.smallFontPointSize
        wrapMode:               Text.WordWrap
        text:                   qsTr("注意：为了获得最佳性能，请在“一般”页面上禁用UDP设备的自动连接。")
    }

    RowLayout {
        spacing: _colSpacing

        QGCLabel { text: qsTr("端口") }
        QGCTextField {
            id:                     portField
            text:                   subEditConfig.localPort.toString()
            focus:                  true
            Layout.preferredWidth:  _secondColumnWidth
            inputMethodHints:       Qt.ImhFormattedNumbersOnly
            onTextChanged:          subEditConfig.localPort = parseInt(portField.text)
        }
    }

    QGCLabel { text: qsTr("服务器地址（可选）") }

    Repeater {
        model: subEditConfig.hostList

        delegate: RowLayout {
            spacing: _colSpacing

            QGCLabel {
                Layout.preferredWidth:  _secondColumnWidth
                text:                   modelData
            }

            QGCButton {
                text:       qsTr("删除")
                onClicked:  subEditConfig.removeHost(modelData)
            }
        }
    }

    RowLayout {
        spacing: _colSpacing

        QGCTextField {
            id:                     hostField
            Layout.preferredWidth:  _secondColumnWidth
            placeholderText:        qsTr("示例：127.0.0.1:14550")
        }
        QGCButton {
            text:       qsTr("添加服务器")
            enabled:    hostField.text !== ""
            onClicked: {
                subEditConfig.addHost(hostField.text)
                hostField.text = ""
            }
        }
    }
}
