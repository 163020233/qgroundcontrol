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
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FactSystem
import QGroundControl.ScreenTools
import QGroundControl.SettingsManager

ColumnLayout {
    spacing: _rowSpacing

    property Fact _loginFact: QGroundControl.settingsManager.appSettings.loginAirLink
    property Fact _passFact: QGroundControl.settingsManager.appSettings.passAirLink

    function saveSettings() {
        // No need
    }

    function updateConnectionName(modem) {
        nameField.text = "Airlink " + modem
    }

    GridLayout {
        columns:        2
        columnSpacing:  _colSpacing
        rowSpacing:     _rowSpacing

        QGCLabel { text: qsTr("登录:") }
        QGCTextField {
            id:                     loginField
            text:                   _loginFact.rawValue
            focus:                  true
            Layout.preferredWidth:  _secondColumnWidth
            onTextChanged:          subEditConfig.username = loginField.text
        }

        QGCLabel { text: qsTr("密码:") }
        QGCTextField {
            id:                     passwordField
            text:                   _passFact.rawValue
            focus:                  true
            Layout.preferredWidth:  _secondColumnWidth
            echoMode:               TextInput.Password
            onTextChanged:          subEditConfig.password = passwordField.text
        }
    }

    QGCLabel {
        text: "Forgot Your AirLink Password?"
        font.underline: true
        Layout.columnSpan:  2
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("https://air-link.space/forgot-pass")
        }
    }

    RowLayout {
        spacing:  _colSpacing

        QGCLabel {
            wrapMode: Text.WordWrap
            text: qsTr("没有账号?")
        }

        QGCLabel {
            font.underline: true
            wrapMode: Text.WordWrap
            text: qsTr("注册")
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://air-link.space/registration")
            }
        }
    }

    QGCLabel { text: qsTr("可用设备列表") }

    RowLayout {
        QGCComboBox {
            Layout.fillWidth: true
            model:            QGroundControl.airlinkManager.droneList
            onActivated: {
                subEditConfig.modemName = QGroundControl.airlinkManager.droneList[index]
                updateConnectionName(subEditConfig.modemName)
            }

            Connections {
                target: QGroundControl.airlinkManager
                // model update does not trigger onActivated, so we catch first element manually
                onDroneListChanged: {
                    if (QGroundControl.airlinkManager.droneList[0] !== undefined) {
                        subEditConfig.modemName = QGroundControl.airlinkManager.droneList[0]
                        updateConnectionName(subEditConfig.modemName)
                    }
                }
            }
        }

        QGCButton {
            text: qsTr("刷新")
            onClicked:  {
                QGroundControl.airlinkManager.updateDroneList(loginField.text, passwordField.text)
                refreshHint.visible = false
                QGroundControl.airlinkManager.updateCredentials(loginField.text, passwordField.text)
            }
        }
    }

    QGCLabel {
        id: refreshHint
        Layout.fillWidth: true
        font.pointSize: ScreenTools.smallFontPointSize
        wrapMode: Text.WordWrap
        text: qsTr("点击 \"刷新\" 以授权")
    }
}
