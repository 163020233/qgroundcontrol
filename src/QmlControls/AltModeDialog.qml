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

QGCPopupDialog {
    title:   qsTr("选择高度模式")
    buttons: Dialog.Close

    property var rgRemoveModes
    property var updateAltModeFn
    property var currentAltMode

    Component.onCompleted: {
        // Check for custom build override on AMSL usage
        if (!QGroundControl.corePlugin.options.showMissionAbsoluteAltitude && currentAltMode != QGroundControl.AltitudeModeAbsolute) {
            rgRemoveModes.push(QGroundControl.AltitudeModeAbsolute)
        }

        // Remove modes specified by consumer
        for (var i=0; i<rgRemoveModes.length; i++) {
            for (var j=0; j<buttonModel.count; j++) {
                if (buttonModel.get(j).modeValue == rgRemoveModes[i]) {
                    buttonModel.remove(j)
                    break
                }
            }
        }


        buttonRepeater.model = buttonModel
    }

    ListModel {
        id: buttonModel

        ListElement {
            modeName:   qsTr("相对起飞高度")
            help:       qsTr("指定高度是相对于起飞位置高度的。")
            modeValue:  QGroundControl.AltitudeModeRelative
        }
        ListElement {
            modeName:   qsTr("AMSL")
            help:       qsTr("指定高度是海平面高度。")
            modeValue:  QGroundControl.AltitudeModeAbsolute
        }
        ListElement {
            modeName:   qsTr("计算高度")
            help:       qsTr("指定高度是相对于地形高度的。")
            modeValue:  QGroundControl.AltitudeModeCalcAboveTerrain
        }
        ListElement {
            modeName:   qsTr("地形框架")
            help:       qsTr("指定高度是指高于地形的距离。实际飞行高度由飞行器根据地形高度图或距离传感器控制。")
            modeValue:  QGroundControl.AltitudeModeTerrainFrame
        }
        ListElement {
            modeName:   qsTr("混合模式")
            help:       qsTr("高度模式可以为每个项目单独设置。")
            modeValue:  QGroundControl.AltitudeModeMixed
        }
    }

    Column {
        spacing: ScreenTools.defaultFontPixelWidth

        Repeater {
            id: buttonRepeater

            Button {
                hoverEnabled:   true
                checked:        modeValue == currentAltMode

                background: Rectangle {
                    radius: ScreenTools.defaultFontPixelHeight / 2
                    color:  pressed | hovered | checked ? QGroundControl.globalPalette.buttonHighlight: QGroundControl.globalPalette.button
                }

                contentItem: Column {
                    spacing: 0

                    QGCLabel {
                        id:     modeNameLabel
                        text:   modeName
                        color:  pressed | hovered | checked ? QGroundControl.globalPalette.buttonHighlightText: QGroundControl.globalPalette.buttonText
                    }

                    QGCLabel {
                        width:              ScreenTools.defaultFontPixelWidth * 40
                        text:               help
                        wrapMode:           Label.WordWrap
                        font.pointSize:     ScreenTools.smallFontPointSize
                        color:              modeNameLabel.color
                    }
                }

                onClicked: {
                    updateAltModeFn(modeValue)
                    close()
                }
            }
        }
    }
}
