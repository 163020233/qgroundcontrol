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

import QGroundControl
import QGroundControl.Controls
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.FactSystem

RowLayout {
    id:         control
    spacing:    ScreenTools.defaultFontPixelWidth

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property var    _vehicleInAir:      _activeVehicle ? _activeVehicle.flying || _activeVehicle.landing : false
    property bool   _vtolInFWDFlight:   _activeVehicle ? _activeVehicle.vtolInFwdFlight : false
    property bool   _armed:             _activeVehicle ? _activeVehicle.armed : false
    property real   _margins:           ScreenTools.defaultFontPixelWidth
    property real   _spacing:           ScreenTools.defaultFontPixelWidth / 2
    property bool   _healthAndArmingChecksSupported: _activeVehicle ? _activeVehicle.healthAndArmingCheckReport.supported : false

    function dropMainStatusIndicator() {
        let overallStatusComponent = _activeVehicle ? overallStatusIndicatorPage : overallStatusOfflineIndicatorPage
        mainWindow.showIndicatorDrawer(overallStatusComponent, control)
    }

    QGCLabel {
        id:                 mainStatusLabel
        // 主菜单栏
        Layout.fillHeight:  true
        Layout.preferredWidth: contentWidth + vehicleMessagesIcon.width + control.spacing
        verticalAlignment:  Text.AlignVCenter
        text:               mainStatusText()
        font.pointSize:     ScreenTools.largeFontPointSize

        property string _commLostText:      qsTr("通讯中断")
        property string _readyToFlyText:    qsTr("准备起飞")
        property string _notReadyToFlyText: qsTr("未准备")
        property string _disconnectedText:  qsTr("连接")
        property string _armedText:         qsTr("已解锁")
        property string _flyingText:        qsTr("正在飞行")
        property string _landingText:       qsTr("正在降落")

        function mainStatusText() {
            var statusText
            if (_activeVehicle) {
                if (_communicationLost) {
                    _mainStatusBGColor = "red"
                    return mainStatusLabel._commLostText
                }
                if (_activeVehicle.armed) {
                    _mainStatusBGColor = "green"

                    if (_healthAndArmingChecksSupported) {
                        if (_activeVehicle.healthAndArmingCheckReport.canArm) {
                            if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
                                _mainStatusBGColor = "yellow"
                            }
                        } else {
                            _mainStatusBGColor = "red"
                        }
                    }

                    if (_activeVehicle.flying) {
                        return mainStatusLabel._flyingText
                    } else if (_activeVehicle.landing) {
                        return mainStatusLabel._landingText
                    } else {
                        return mainStatusLabel._armedText
                    }
                } else {
                    if (_healthAndArmingChecksSupported) {
                        if (_activeVehicle.healthAndArmingCheckReport.canArm) {
                            if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
                                _mainStatusBGColor = "yellow"
                            } else {
                                _mainStatusBGColor = "green"
                            }
                            return mainStatusLabel._readyToFlyText
                        } else {
                            _mainStatusBGColor = "red"
                            return mainStatusLabel._notReadyToFlyText
                        }
                    } else if (_activeVehicle.readyToFlyAvailable) {
                        if (_activeVehicle.readyToFly) {
                            _mainStatusBGColor = "green"
                            return mainStatusLabel._readyToFlyText
                        } else {
                            _mainStatusBGColor = "yellow"
                            return mainStatusLabel._notReadyToFlyText
                        }
                    } else {
                        // 默认配置OK,传感器OK
                        // Best we can do is determine readiness based on AutoPilot component setup and health indicators from SYS_STATUS
                        if (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin.setupComplete) {
                            _mainStatusBGColor = "green"
                            return mainStatusLabel._readyToFlyText
                        } else {
                            _mainStatusBGColor = "yellow"
                            return mainStatusLabel._notReadyToFlyText
                        }
                    }
                }
            } else {
                _mainStatusBGColor = qgcPal.brandingPurple
                return mainStatusLabel._disconnectedText
            }
        }

        QGCColoredImage {
            id:                     vehicleMessagesIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            width:                  ScreenTools.defaultFontPixelWidth * 2
            height:                 width
            source:                 "/res/VehicleMessage.svg"
            color:                  getIconColor()
            sourceSize.width:       width
            fillMode:               Image.PreserveAspectFit
            //visible:                _activeVehicle && _activeVehicle.messageCount > 0// FIXME: Is messageCount check needed?

            function getIconColor() {
                let iconColor = qgcPal.text
                if (_activeVehicle) {
                    if (_activeVehicle.messageTypeWarning) {
                        iconColor = qgcPal.colorOrange
                    } else if (_activeVehicle.messageTypeError) {
                        iconColor = qgcPal.colorRed
                    }
                }
                return iconColor
            }
        }

        QGCMouseArea {
            anchors.fill:   parent
            onClicked:      dropMainStatusIndicator()
        }
    }

    QGCLabel {
        id:                 vtolModeLabel
        Layout.fillHeight:  true
        verticalAlignment:  Text.AlignVCenter
        text:               _vtolInFWDFlight ? qsTr("FW(vtol)") : qsTr("MR(vtol)")
        font.pointSize:     _vehicleInAir ? ScreenTools.largeFontPointSize : ScreenTools.defaultFontPointSize
        visible:            _activeVehicle && _activeVehicle.vtol

        QGCMouseArea {
            anchors.fill: parent
            onClicked: {
                if (_vehicleInAir) {
                    mainWindow.showIndicatorDrawer(vtolTransitionIndicatorPage)
                }
            }
        }
    }

    Component {
        id: overallStatusOfflineIndicatorPage

        MainStatusIndicatorOfflinePage { }
    }

    Component {
        id: overallStatusIndicatorPage

        ToolIndicatorPage {
            showExpand:         _activeVehicle.mainStatusIndicatorContentItem ? true : false
            waitForParameters:  _activeVehicle.mainStatusIndicatorContentItem ? true : false
            contentComponent:   mainStatusContentComponent
            expandedComponent:  mainStatusExpandedComponent
        }
    }


    Component {
        id: mainStatusContentComponent

        ColumnLayout {
            id: mainLayout
            spacing: _spacing

            // 水平排列：无人机按钮 + 断开连接按钮
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth / 2

                // Arm / Disarm 按钮
                QGCButton {
                    enabled: _armed || !_healthAndArmingChecksSupported || _activeVehicle.healthAndArmingCheckReport.canArm
                    text: _armed ? qsTr("已上锁") : (forceArm ? qsTr("无人机") : qsTr("无人机"))
                    Layout.alignment: Qt.AlignLeft

                    property bool forceArm: false

                    onPressAndHold: forceArm = true

                    onClicked: {
                        if (_armed) {
                            mainWindow.disarmVehicleRequest()
                        } else {
                            if (forceArm) {
                                mainWindow.forceArmVehicleRequest()
                            } else {
                                mainWindow.armVehicleRequest()
                            }
                        }
                        forceArm = false
                        mainWindow.closeIndicatorDrawer()
                    }
                }

                // 断开连接按钮
                QGCButton {
                    text: qsTr("断开连接")
                    enabled: _activeVehicle != null  // 只要有活动无人机就允许点击
                    visible: _activeVehicle != null
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.closeVehicle()   // 安全断开
                            mainWindow.closeIndicatorDrawer()  // 关闭当前控件/抽屉
                        } else {
                            console.log("无活动无人机")
                        }
                    }
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("设备消息")
                visible:            !vehicleMessageList.noMessages

                VehicleMessageList { 
                    id: vehicleMessageList
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("传感器状态")  
                //visible:            !_healthAndArmingChecksSupported
                visible: !_healthAndArmingChecksSupported
                    && _activeVehicle.sysStatusSensorInfo.sensorNames.length > 0

                GridLayout {
                    rowSpacing:     _spacing
                    columnSpacing:  _spacing
                    rows:           _activeVehicle.sysStatusSensorInfo.sensorNames.length
                    flow:           GridLayout.TopToBottom

                    Repeater {
                        model: _activeVehicle.sysStatusSensorInfo.sensorNames
                        QGCLabel { text: modelData }
                    }

                    Repeater {
                        model: _activeVehicle.sysStatusSensorInfo.sensorStatus
                        QGCLabel { text: modelData }
                    }
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("总体状况")
                visible:            _healthAndArmingChecksSupported && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0

                // List health and arming checks
                Repeater {
                    model:      _activeVehicle ? _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode : null
                    delegate:   listdelegate
                }
            }

            FactPanelController {
                id: controller
            }

            Component {
                id: listdelegate

                Column {
                    Row {
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            id:           message
                            text:         object.message
                            textFormat:   TextEdit.RichText
                            color:        object.severity == 'error' ? qgcPal.colorRed : object.severity == 'warning' ? qgcPal.colorOrange : qgcPal.text
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (object.description != "")
                                        object.expanded = !object.expanded
                                }
                            }
                        }

                        QGCColoredImage {
                            id:                     arrowDownIndicator
                            anchors.verticalCenter: parent.verticalCenter
                            height:                 1.5 * ScreenTools.defaultFontPixelWidth
                            width:                  height
                            source:                 "/qmlimages/arrow-down.png"
                            color:                  qgcPal.text
                            visible:                object.description != ""
                            MouseArea {
                                anchors.fill:       parent
                                onClicked:          object.expanded = !object.expanded
                            }
                        }
                    }

                    QGCLabel {
                        id:                 description
                        text:               object.description
                        textFormat:         TextEdit.RichText
                        clip:               true
                        visible:            object.expanded
                        
                        property var fact:  null

                        onLinkActivated: (link) => {
                            if (link.startsWith('param://')) {
                                var paramName = link.substr(8);
                                fact = controller.getParameterFact(-1, paramName, true)
                                if (fact != null) {
                                    paramEditorDialogComponent.createObject(mainWindow).open()
                                }
                            } else {
                                Qt.openUrlExternally(link);
                            }
                        }

                        Component {
                            id: paramEditorDialogComponent

                            ParameterEditorDialog {
                                title:          qsTr("编辑参数")
                                fact:           description.fact
                                destroyOnClose: true
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mainStatusExpandedComponent

        ColumnLayout {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 60
            spacing:                margins / 2

            property real margins: ScreenTools.defaultFontPixelHeight

            Loader {
                source: _activeVehicle.mainStatusIndicatorContentItem
            }

            // SettingsGroupLayout {
            //     Layout.fillWidth:   true
            //     visible:            QGroundControl.corePlugin.showAdvancedUI
            //
            //     GridLayout {
            //         columns:            2
            //         rowSpacing:         ScreenTools.defaultFontPixelHeight / 2
            //         columnSpacing:      ScreenTools.defaultFontPixelWidth *2
            //         Layout.fillWidth:   true
            //
            //         QGCLabel { Layout.fillWidth: true; text: qsTr("设备参数") }
            //         QGCButton {
            //             text: qsTr("配置")
            //             onClicked: {
            //                 mainWindow.showVehicleConfigParametersPage()
            //                 mainWindow.closeIndicatorDrawer()
            //             }
            //         }
            //
            //         QGCLabel { Layout.fillWidth: true; text: qsTr("设备配置") }
            //         QGCButton {
            //             text: qsTr("配置")
            //             onClicked: {
            //                 mainWindow.showVehicleConfig()
            //                 mainWindow.closeIndicatorDrawer()
            //             }
            //         }
            //     }
            // }
        }
    }

    Component {
        id: vtolTransitionIndicatorPage

        ToolIndicatorPage {
            contentComponent: Component {
                QGCButton {
                    text: _vtolInFWDFlight ? qsTr("转换为多旋翼") : qsTr("转换为固定翼")

                    onClicked: {
                        if (_vtolInFWDFlight) {
                            mainWindow.vtolTransitionToMRFlightRequest()
                        } else {
                            mainWindow.vtolTransitionToFwdFlightRequest()
                        }
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }
        }
    }
}

