/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Controls
import QGroundControl.Palette

Item {
    id: control
    implicitWidth: mainLayout.width + (_toolsMargin * 2)
    implicitHeight: mainLayout.height + (_toolsMargin * 2)

    property real extraWidth: 0 ///< Extra width to add to the background rectangle

    property alias factValueGrid: factValueGrid
    property alias settingsGroup: factValueGrid.settingsGroup
    property alias specificVehicleForCard: factValueGrid.specificVehicleForCard

    Rectangle {
        id: backgroundRect
        width: control.width + extraWidth
        height: control.height * 2
        color: qgcPal.window
        radius: ScreenTools.defaultFontPixelWidth / 2
        opacity: 0.75
        //更改透明度
    }

    // 布局是一个垂直 ColumnLayout。
    // 通过 _toolsMargin 设置内边距。
    // 固定在父控件左下角。
    ColumnLayout {
        id: mainLayout
        anchors.margins: _toolsMargin
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        //解锁图标
        RowLayout {
            visible: factValueGrid.settingsUnlocked

            QGCColoredImage {
                source:             "qrc:/InstrumentValueIcons/lock-open.svg"
                mipmap: true
                width: ScreenTools.minTouchPixels * 0.75
                height: width
                sourceSize.width: width
                color: qgcPal.text
                fillMode: Image.PreserveAspectFit

                QGCMouseArea {
                    anchors.fill: parent
                    // onClicked: factValueGrid.settingsUnlocked = false
                    onClicked: {
                        console.log("Lock icon clicked!")
                        factValueGrid.removeFactByName("AltitudeRelative")
                        factValueGrid.settingsUnlocked = false
                    }
                }
            }
        }

        // HorizontalFactValueGrid 是 QGC 自定义组件，用于水平显示参数（fact）的值。
        HorizontalFactValueGrid {
            id: factValueGrid
        }
    }

    Connections {
        target: factValueGrid
        onSettingsUnlockedChanged: {
            if (!factValueGrid.settingsUnlocked) {
                factValueGrid.removeFactByName("AltitudeRelative")
            }
        }
    }

    QGCMouseArea {
        id: mouseArea
        x: mainLayout.x
        y: mainLayout.y
        width: mainLayout.width
        height: mainLayout.height
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        visible: !factValueGrid.settingsUnlocked

        onClicked: (mouse) => {
            if (!ScreenTools.isMobile && mouse.button === Qt.RightButton) {
                factValueGrid.settingsUnlocked = true
                mouse.accepted = true
            }
        }

        onPressAndHold: {
            factValueGrid.settingsUnlocked = true
            mouse.accepted = true
        }
    }
}
