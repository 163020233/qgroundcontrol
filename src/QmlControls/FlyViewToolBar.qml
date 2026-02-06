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
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.MultiVehicleManager
import QGroundControl.ScreenTools
import QGroundControl.Controllers

Rectangle {
    id:     _root
    width:  parent.width
    height: ScreenTools.toolbarHeight*1.1
    //color:  qgcPal.toolbarBackground
    // 逻辑：借用系统主题的 R/G/B 颜色，但强行覆盖 Alpha 为 0.7
    color: Qt.rgba(0, 0, 0, 0.5)

    // 🔹 自定义属性，绑定 Plan 页的 MainStatusIndicator
    // property var mainStatusLabelLogic: null

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         0
        color:          "black"
        visible:        qgcPal.globalTheme === QGCPalette.Light
    }

    // Rectangle {
    //     anchors.fill: viewButtonRow
    //     anchors.rightMargin: -20  // 向右延伸 20 像素
    //     gradient: Gradient {
    //         orientation: Gradient.Horizontal
    //         GradientStop { position: 0;                                     color: _mainStatusBGColor}
    //         GradientStop { position: currentButton.x + currentButton.width; color: _mainStatusBGColor }
    //         GradientStop { position: 1;                                     color:  _mainStatusBGColor }
    //     }
    // }


    // Canvas {
    //     id: planToolBarCanvas
    //     anchors.fill: parent
    //
    //     onPaint: {
    //         var ctx = getContext("2d")
    //         ctx.clearRect(0, 0, width, height)
    //
    //         // 🔹 安全读取颜色
    //         var color = planMainStatus
    //             && planMainStatus._mainStatusBGColor
    //             ? planMainStatus._mainStatusBGColor
    //             : "#C0C0C0"  // 默认浅灰色
    //
    //         var gradient = ctx.createLinearGradient(0, 0, width, 0)
    //         gradient.addColorStop(0, color)
    //         gradient.addColorStop(1, Qt.lighter(color, 1.4))
    //         ctx.fillStyle = gradient
    //
    //         ctx.beginPath()
    //         ctx.moveTo(0, 0)
    //         ctx.lineTo(width - 20, 0)
    //         ctx.lineTo(width, height)
    //         ctx.lineTo(0, height)
    //         ctx.closePath()
    //         ctx.fill()
    //     }
    // }

    Canvas {
        id: trapezoidBackground
        anchors.fill: viewButtonRow
        anchors.rightMargin: -20   // 向右延伸一点
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // 创建横向渐变
            var gradient = ctx.createLinearGradient(0, 0, width, 0)
            gradient.addColorStop(0, _mainStatusBGColor)
            gradient.addColorStop(
                Math.min(1, (currentButton.x + currentButton.width) / width),
                _mainStatusBGColor
            )
            gradient.addColorStop(1, Qt.lighter(_mainStatusBGColor, 1.4))  // 右侧更亮一些
            // 或者：gradient.addColorStop(1, "rgba(255,255,255,0.1)") // 渐隐
            //         GradientStop { position: 0;                                     color: _mainStatusBGColor}
            //         GradientStop { position: currentButton.x + currentButton.width; color: _mainStatusBGColor }
            //         GradientStop { position: 1;                                     color:  _mainStatusBGColor }

            ctx.fillStyle = gradient

            // 绘制梯形：上边与下边不平行
            ctx.beginPath()
            ctx.moveTo(0, 0)              // 左上角
            ctx.lineTo(width - 20, 0)     // 右上角（向左缩一点）
            ctx.lineTo(width, height)     // 右下角（斜线边）
            ctx.lineTo(0, height)         // 左下角
            ctx.closePath()
            ctx.fill()
        }
    }

    RowLayout {
        id:                     viewButtonRow
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCToolBarButton {
            id:                     currentButton
            Layout.preferredHeight: viewButtonRow.height
            icon.source:            "/res/QJKJ.png"
            logo:                   true
            onClicked:              mainWindow.showToolSelectDialog()
        }

        MainStatusIndicator {
            id: mainStatusIndicator
            Layout.preferredHeight: viewButtonRow.height
        }

        QGCButton {
            id:                 disconnectButton
            text:               qsTr("断开连接")
            onClicked:          _activeVehicle.closeVehicle()
            visible:            _activeVehicle && _communicationLost
        }
    }

    // QGCFlickable {
    //     id:                     toolsFlickable
    //     anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio * 1.5
    //     anchors.rightMargin:    ScreenTools.defaultFontPixelWidth / 2
    //     anchors.left:           viewButtonRow.right
    //     anchors.bottomMargin:   1
    //     anchors.top:            parent.top
    //     anchors.bottom:         parent.bottom
    //     anchors.right:          parent.right
    //     contentWidth:           toolIndicators.width
    //     flickableDirection:     Flickable.HorizontalFlick
    //
    //     FlyViewToolBarIndicators { id: toolIndicators }
    // }
    Row {
        id:                     toolIndicatorsRow
        anchors.left:           viewButtonRow.right   // 👈 如果左边有按钮组，保留这一行
        anchors.right:          parent.right          // 👈 贴到最右边
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth / 2
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio * 1.5
        spacing:                ScreenTools.defaultFontPixelWidth * 1.85

        FlyViewToolBarIndicators {
            id: toolIndicators
        }
    }
    //-------------------------------------------------------------------------
    //-- Branding Logo
    // Image {
    //     anchors.right:          parent.right
    //     anchors.top:            parent.top
    //     anchors.bottom:         parent.bottom
    //     anchors.margins:        ScreenTools.defaultFontPixelHeight * 0.66
    //     visible:                _activeVehicle && !_communicationLost && x > (toolsFlickable.x + toolsFlickable.contentWidth + ScreenTools.defaultFontPixelWidth)
    //     fillMode:               Image.PreserveAspectFit
    //     source:                 _outdoorPalette ? _brandImageOutdoor : _brandImageIndoor
    //     mipmap:                 true
    //
    //     property bool   _outdoorPalette:        qgcPal.globalTheme === QGCPalette.Light
    //     property bool   _corePluginBranding:    QGroundControl.corePlugin.brandImageIndoor.length != 0
    //     property string _userBrandImageIndoor:  QGroundControl.settingsManager.brandImageSettings.userBrandImageIndoor.value
    //     property string _userBrandImageOutdoor: QGroundControl.settingsManager.brandImageSettings.userBrandImageOutdoor.value
    //     property bool   _userBrandingIndoor:    QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageIndoor.length != 0
    //     property bool   _userBrandingOutdoor:   QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageOutdoor.length != 0
    //     property string _brandImageIndoor:      brandImageIndoor()
    //     property string _brandImageOutdoor:     brandImageOutdoor()
    //
    //     function brandImageIndoor() {
    //         if (_userBrandingIndoor) {
    //             return _userBrandImageIndoor
    //         } else {
    //             if (_userBrandingOutdoor) {
    //                 return _userBrandImageOutdoor
    //             } else {
    //                 if (_corePluginBranding) {
    //                     return QGroundControl.corePlugin.brandImageIndoor
    //                 } else {
    //                     return _activeVehicle ? _activeVehicle.brandImageIndoor : ""
    //                 }
    //             }
    //         }
    //     }
    //
    //     function brandImageOutdoor() {
    //         if (_userBrandingOutdoor) {
    //             return _userBrandImageOutdoor
    //         } else {
    //             if (_userBrandingIndoor) {
    //                 return _userBrandImageIndoor
    //             } else {
    //                 if (_corePluginBranding) {
    //                     return QGroundControl.corePlugin.brandImageOutdoor
    //                 } else {
    //                     return _activeVehicle ? _activeVehicle.brandImageOutdoor : ""
    //                 }
    //             }
    //         }
    //     }
    // }

    // Small parameter download progress bar
    Rectangle {
        anchors.bottom: parent.bottom
        height:         _root.height * 0.05
        width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
        color:          qgcPal.colorGreen
        visible:        !largeProgressBar.visible
    }

    // Large parameter download progress bar
    // 深度定制版参数同步显示器
    Rectangle {
        id:             largeProgressBar
        anchors.fill:   parent
        color:          "#E6000000" // 90% 透明度的纯黑
        visible:        _showLargeProgress

        property bool _initialDownloadComplete: _activeVehicle ? _activeVehicle.initialConnectComplete : true
        property bool _userHide:                false
        // 移除了主题限制，确保暗色模式也能看到
        property bool _showLargeProgress:       !_initialDownloadComplete && !_userHide

        // 背景进度（深绿色）
        Rectangle {
            anchors.fill:   parent
            width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
            color:          qgcPal.colorGreen
            opacity:        0.2 // 淡淡的绿色铺满背景
        }

        // 底部高亮进度条（亮绿色）
        Rectangle {
            anchors.bottom: parent.bottom
            height:         3 // 只有 3 像素高
            width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
            color:          qgcPal.colorGreen
            Behavior on width { NumberAnimation { duration: 500 } }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth

            // 增加一个小转圈动画，显得系统没死机
            BusyIndicator {
                width: 20; height: 20
                running: largeProgressBar.visible
            }

            QGCLabel {
                text: qsTr("系统参数同步中 %1%").arg(Math.round(_activeVehicle ? _activeVehicle.loadProgress * 100 : 0))
                font.bold: true
                color: "white"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked:    largeProgressBar._userHide = true
        }
    }
    // Rectangle {
    //     id:             largeProgressBar
    //     anchors.bottom: parent.bottom
    //     anchors.left:   parent.left
    //     anchors.right:  parent.right
    //     height:         parent.height
    //     color:          qgcPal.window
    //     visible:        _showLargeProgress
    //
    //     property bool _initialDownloadComplete: _activeVehicle ? _activeVehicle.initialConnectComplete : true
    //     property bool _userHide:                false
    //     property bool _showLargeProgress:       !_initialDownloadComplete && !_userHide && qgcPal.globalTheme === QGCPalette.Light
    //
    //     Connections {
    //         target:                 QGroundControl.multiVehicleManager
    //         function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
    //     }
    //
    //     Rectangle {
    //         anchors.top:    parent.top
    //         anchors.bottom: parent.bottom
    //         width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
    //         color:          qgcPal.colorGreen
    //     }
    //
    //     QGCLabel {
    //         anchors.centerIn:   parent
    //         text:               qsTr("下载中")
    //         font.pointSize:     ScreenTools.largeFontPointSize
    //     }
    //
    //     QGCLabel {
    //         anchors.margins:    _margin
    //         anchors.right:      parent.right
    //         anchors.bottom:     parent.bottom
    //         text:               qsTr("点击任意位置隐藏")
    //
    //         property real _margin: ScreenTools.defaultFontPixelWidth / 2
    //     }
    //
    //     MouseArea {
    //         anchors.fill:   parent
    //         onClicked:      largeProgressBar._userHide = true
    //     }
    // }
}
