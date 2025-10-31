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

import QGroundControl
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.Vehicle
import QGroundControl.Controllers
import QGroundControl.FlightMap.Widgets

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    property double _ar:                QGroundControl.videoManager.gstreamerEnabled
                                            ? QGroundControl.videoManager.videoSize.width / QGroundControl.videoManager.videoSize.height
                                            : QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property bool   _isMode_FIT_WIDTH:  _fitMode === 0
    property bool   _isMode_FIT_HEIGHT: _fitMode === 1
    property bool   _isMode_FILL:       _fitMode === 2
    property bool   _isMode_NO_CROP:    _fitMode === 3
    property bool _isFullScreen: _fullItem ? _fullItem.pipState.state === _fullItem.pipState.fullState : false

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    property double _thermalHeightFactor: 0.85 //-- TODO

    //无视频时的背景（NoVideoBackground.jpg）
    // 无视频时的背景
    Rectangle {
        id:             noVideo
        anchors.fill:   parent
        visible:        !(QGroundControl.videoManager.decoding)

        // 使用渐变代替纯色
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.7) }   // 顶部更深
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.4) }   // 底部更浅
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; hoverEnabled: false }

        Rectangle {
            anchors.centerIn:   parent
            width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
            height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
            radius:             ScreenTools.defaultFontPixelWidth / 2
            color:              Qt.rgba(0, 0, 0, 0.5)
        }

        QGCLabel {
            id:                 noVideoLabel
            text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue
                ? qsTr("等待视频")
                : qsTr("视频已禁用")
            font.bold:          true
            color:              "white"
            font.pointSize:     useSmallFont
                ? ScreenTools.smallFontPointSize
                : ScreenTools.largeFontPointSize
            anchors.centerIn:   parent
        }
    }

    //     Image {
    //         id:             noVideo
    //         anchors.fill:   parent
    //         source:         "/res/NoVideoBackground.jpg"
    //         fillMode:       Image.PreserveAspectCrop
    //         visible:        !(QGroundControl.videoManager.decoding)
    //
    //         // 关键：不接收鼠标事件
    //         MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; hoverEnabled: false }
    //
    //         Rectangle {
    //             anchors.centerIn:   parent
    //             width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
    //             height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
    //             radius:             ScreenTools.defaultFontPixelWidth / 2
    //             color:              "black"
    //             opacity:            0.5
    //         }
    //
    //         QGCLabel {
    //             id:                 noVideoLabel
    //             text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue ? qsTr("等待视频") : qsTr("视频已禁用")
    //             font.bold:          true
    //             color:              "white"
    //             font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
    //             anchors.centerIn:   parent
    //         }
    //     }

        //视频背景容器（videoBackground）
    Rectangle {
        id:             videoBackground
        anchors.fill:   parent
        color:          "black"
        visible:        QGroundControl.videoManager.decoding
        function getWidth() {
            if(_ar != 0.0){
                if(_isMode_FIT_HEIGHT 
                        || (_isMode_FILL && (root.width/root.height < _ar))
                        || (_isMode_NO_CROP && (root.width/root.height > _ar))){
                    // This return value has different implications depending on the mode
                    // For FIT_HEIGHT and FILL
                    //    makes so the video width will be larger than (or equal to) the screen width
                    // For NO_CROP Mode
                    //    makes so the video width will be smaller than (or equal to) the screen width
                    return root.height * _ar
                }
            }
            return root.width
        }
        function getHeight() {
            if(_ar != 0.0){
                if(_isMode_FIT_WIDTH 
                        || (_isMode_FILL && (root.width/root.height > _ar)) 
                        || (_isMode_NO_CROP && (root.width/root.height < _ar))){
                    // This return value has different implications depending on the mode
                    // For FIT_WIDTH and FILL
                    //    makes so the video height will be larger than (or equal to) the screen height
                    // For NO_CROP Mode
                    //    makes so the video height will be smaller than (or equal to) the screen height
                    return root.width * (1 / _ar)
                }
            }
            return root.height
        }
        Component {
            id: videoBackgroundComponent
            QGCVideoBackground {
                id:             videoContent
                objectName:     "videoContent"

                Connections {
                    target: QGroundControl.videoManager
                    function onImageFileChanged(filename) {
                        videoContent.grabToImage(function(result) {
                            if (!result.saveToFile(filename)) {
                                console.error('Error capturing video frame');
                            }
                        });
                    }
                }

                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
            }
        }
        //负责加载 QGCVideoBackground（视频播放渲染）
        Loader {
            // GStreamer is causing crashes on Lenovo laptop OpenGL Intel drivers. In order to workaround this
            // we don't load a QGCVideoBackground object when video is disabled. This prevents any video rendering
            // code from running. Hence the Loader to completely remove it.
            height:             parent.getHeight()
            width:              parent.getWidth()
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.decoding
            sourceComponent:    videoBackgroundComponent

            property bool videoDisabled: QGroundControl.settingsManager.videoSettings.videoSource.rawValue === QGroundControl.settingsManager.videoSettings.disabledVideoSource
        }

        //-- Thermal Image 热成像叠加视频
        Item {
            id:                 thermalItem
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.hasThermal && _camera.thermalMode !== MavlinkCameraControl.THERMAL_OFF
            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                onThermalModeChanged:   thermalItem.pipOrNot()
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                objectName:     "thermalVideo"
                anchors.fill:   parent
                opacity:        _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }
        }
        //-- Zoom缩放手势
        PinchArea {
            id:             pinchZoom
            enabled:        _hasZoom
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }

    // // ---------- 工具栏层（新加） ----------
    // Rectangle {
    //     id: toolBar
    //     width: parent.width
    //     height: 60
    //     anchors.top: parent.top
    //     color: Qt.rgba(0, 0, 0, 0.3)
    //     z: 9999
    //
    //     // 🔹 条件：主界面是视频页面 + 视频页面状态是 PiP 才显示
    //     visible: _fullItem === item1 && item1.pipState.state === item1.pipState.pipState
    //
    //     Row {
    //         anchors.verticalCenter: parent.verticalCenter
    //         anchors.right: parent.right
    //         anchors.rightMargin: 20
    //         spacing: 20
    //
    //         Rectangle {
    //             width: 40; height: 40; color: "transparent"
    //             Image { anchors.fill: parent; source: "qrc:/res/CogWheels.png"; fillMode: Image.PreserveAspectFit }
    //             MouseArea { anchors.fill: parent; onClicked: console.log("设置按钮点击") }
    //         }
    //
    //         Rectangle {
    //             width: 40; height: 40; color: "transparent"
    //             Image { anchors.fill: parent; source: "qrc:/res/Gripper.svg"; fillMode: Image.PreserveAspectFit }
    //             MouseArea { anchors.fill: parent; onClicked: console.log("拍照按钮点击") }
    //         }
    //     }
    //
    //     // 🔹 打印状态变化日志
    //     Connections {
    //         target: item1.pipState
    //         onStateChanged: {
    //             const s = item1.pipState.state
    //             if (s === item1.pipState.fullState) {
    //                 console.log("当前状态：全屏")
    //             } else if (s === item1.pipState.pipState) {
    //                 console.log("当前状态：PiP")
    //             } else if (s === item1.pipState.windowState) {
    //                 console.log("当前状态：窗口")
    //             }
    //             console.log("当前主界面:", _fullItem === item1 ? "视频页面" : "其他页面")
    //             console.log("工具栏是否显示:", toolBar.visible)
    //         }
    //     }
    //
    //     // 🔹 监听主界面切换（_fullItem 改变）
    //     Connections {
    //         target: root   // 或者你的外层对象，取决于 _fullItem 的定义
    //         onFullItemChanged: {
    //             console.log("主界面切换:", _fullItem === item1 ? "视频页面" : "其他页面")
    //             console.log("工具栏是否显示:", toolBar.visible)
    //         }
    //     }
    // }



    // Rectangle {
    //     id: toolBar
    //     width: parent.width
    //     height: 60
    //     anchors.top: parent.top
    //     color: Qt.rgba(0, 0, 0, 0.3)
    //     z: 9999   // 保证在背景之上
    //
    //     Row {
    //         anchors.verticalCenter: parent.verticalCenter
    //         anchors.right: parent.right
    //         anchors.rightMargin: 20
    //         spacing: 20
    //
    //         // 示例按钮：设置
    //         Rectangle {
    //             width: 40
    //             height: 40
    //             color: "transparent"
    //
    //             Image {
    //                 anchors.fill: parent
    //                 source: "qrc:/res/CogWheels.png"
    //                 fillMode: Image.PreserveAspectFit
    //             }
    //
    //             MouseArea {
    //                 anchors.fill: parent
    //                 hoverEnabled: true
    //                 onClicked: console.log("✅ 点击设置按钮成功！")
    //             }
    //         }
    //
    //         // 示例按钮：拍照
    //         Rectangle {
    //             width: 40
    //             height: 40
    //             color: "transparent"
    //
    //             Image {
    //                 anchors.fill: parent
    //                 source: "qrc:/res/Gripper.svg"
    //                 fillMode: Image.PreserveAspectFit
    //             }
    //
    //             MouseArea {
    //                 anchors.fill: parent
    //                 hoverEnabled: true
    //                 onClicked: console.log("📸 点击拍照按钮")
    //             }
    //         }
    //
    //         // 其他按钮可以按此模式添加
    //     }
    // }

    // // 相机控制（保持和主界面一样的位置：底部居中）
    // Loader {
    //     id: photoVideoControlLoader
    //     anchors.top: parent.top
    //     anchors.right: parent.right
    //     anchors.topMargin: ScreenTools.defaultFontPixelHeight
    //     anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 8 // 控件往左移动一点
    //     visible: QGroundControl.videoManager.fullScreen  // 只全屏显示
    //     sourceComponent: globals.activeVehicle ? photoVideoControlComponent : undefined
    //
    //     Component {
    //         id: photoVideoControlComponent
    //         PhotoVideoControl {
    //             // 根据视频缩放比例自动调整大小
    //             width: parent.width * 0.25
    //             height: width * (height / width) // 保持原始比例
    //             anchors.top: parent.top
    //             anchors.right: parent.right
    //
    //             // 允许点击
    //             MouseArea {
    //                 anchors.fill: parent
    //                 acceptedButtons: Qt.AllButtons
    //                 onClicked: {
    //                     console.log("PhotoVideoControl 点击")
    //                 }
    //             }
    //         }
    //     }
    // }
    // Loader {
    //     id: photoVideoControlLoader
    //     sourceComponent: globals.activeVehicle ? photoVideoControlComponent : undefined
    //
    //     anchors.top: videoStreaming.top
    //     anchors.right: videoStreaming.right
    //     anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.0
    //     anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 1.0
    //
    //     // 宽高实时绑定视频区域
    //     width: videoStreaming.getWidth() * 0.15
    //     height: videoStreaming.getHeight() * 0.15
    //
    //     visible: QGroundControl.videoManager.fullScreen || videoStreaming._camera
    //
    //     Component {
    //         id: photoVideoControlComponent
    //         PhotoVideoControl {
    //             anchors.fill: parent  // 占满 Loader
    //         }
    //     }
    // }
}
