import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.FactSystem


QGCLabel {
    id: mainStatusLabels
    Layout.fillHeight: true
    Layout.preferredWidth: contentWidth + vehicleMessagesIcon.width + control.spacing
    verticalAlignment: Text.AlignVCenter
    text: mainStatusText()
    font.pointSize: ScreenTools.largeFontPointSize

    // 🔹 状态文本属性，保持 Fly 页一致
    property string _commLostText:      qsTr("通讯中断")
    property string _readyToFlyText:    qsTr("准备起飞")
    property string _notReadyToFlyText: qsTr("未准备")
    property string _disconnectedText:  qsTr("未连接")
    property string _armedText:         qsTr("已解锁")
    property string _flyingText:        qsTr("正在飞行")
    property string _landingText:       qsTr("正在降落")

    // 🔹 状态颜色
    property color _mainStatusBGColor: "#C0C0C0"

    function mainStatusText() {
        _mainStatusBGColor = "#C0C0C0"  // 默认浅灰

        if (!_activeVehicle) {
            _mainStatusBGColor = "#333333"
            return _disconnectedText
        }

        if (_communicationLost) {
            _mainStatusBGColor = "#FF0000"
            return _commLostText
        }

        if (_activeVehicle.armed) {
            _mainStatusBGColor = "#00FF00"
            if (_healthAndArmingChecksSupported) {
                if (!_activeVehicle.healthAndArmingCheckReport.canArm) {
                    _mainStatusBGColor = "#FF0000"
                } else if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
                    _mainStatusBGColor = "#FFFF00"
                }
            }
            if (_activeVehicle.flying) return _flyingText
            if (_activeVehicle.landing) return _landingText
            return _armedText
        } else { // 未解锁
            if (_healthAndArmingChecksSupported) {
                if (!_activeVehicle.healthAndArmingCheckReport.canArm) {
                    _mainStatusBGColor = "#FF0000"
                    return _notReadyToFlyText
                } else if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
                    _mainStatusBGColor = "#FFFF00"
                    return _readyToFlyText
                } else {
                    _mainStatusBGColor = "#00FF00"
                    return _readyToFlyText
                }
            } else if (_activeVehicle.readyToFlyAvailable) {
                if (_activeVehicle.readyToFly) {
                    _mainStatusBGColor = "#00FF00"
                    return _readyToFlyText
                } else {
                    _mainStatusBGColor = "#FFFF00"
                    return _notReadyToFlyText
                }
            } else {
                if (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin.setupComplete) {
                    _mainStatusBGColor = "#00FF00"
                    return _readyToFlyText
                } else {
                    _mainStatusBGColor = "#FFFF00"
                    return _notReadyToFlyText
                }
            }
        }
    }

    // 🔹 Canvas 背景
    Canvas {
        id: planTrapezoidBackground
        anchors.fill: parent
        anchors.rightMargin: -20

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var gradient = ctx.createLinearGradient(0, 0, width, 0)
            gradient.addColorStop(0, mainStatusLabel._mainStatusBGColor)
            gradient.addColorStop(1, Qt.lighter(mainStatusLabel._mainStatusBGColor, 1.4))

            ctx.fillStyle = gradient
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width - 20, 0)
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: mainStatusLabel
            on_mainStatusBGColorChanged: planTrapezoidBackground.requestPaint()
        }
    }

    // 🔹 消息图标
    QGCColoredImage {
        id: vehicleMessagesIcon
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: ScreenTools.defaultFontPixelWidth * 2
        height: width
        source: "/res/VehicleMessage.svg"
        color: getIconColor()
        sourceSize.width: width
        fillMode: Image.PreserveAspectFit

        function getIconColor() {
            var iconColor = qgcPal.text
            if (_activeVehicle) {
                if (_activeVehicle.messageTypeWarning) iconColor = qgcPal.colorOrange
                else if (_activeVehicle.messageTypeError) iconColor = qgcPal.colorRed
            }
            return iconColor
        }
    }

    QGCMouseArea {
        anchors.fill: parent
        onClicked: dropMainStatusIndicator()
    }
}
