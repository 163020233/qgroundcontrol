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

import QGroundControl.ScreenTools
import QGroundControl.Palette

Button {
    id:             control
    width:          contentLayoutItem.contentWidth + (contentMargins * 2)
    height:         width
    hoverEnabled:   !ScreenTools.isMobile
    enabled:        toolStripAction.enabled
    visible:        toolStripAction.visible
    imageSource:    toolStripAction.showAlternateIcon ? modelData.alternateIconSource : modelData.iconSource
    text:           toolStripAction.text
    checked:        toolStripAction.checked
    checkable:      toolStripAction.dropPanelComponent || modelData.checkable

    property var    toolStripAction:    undefined
    property var    dropPanel:          undefined
    property alias  radius:             buttonBkRect.radius
    property alias  fontPointSize:      innerText.font.pointSize
    property alias  imageSource:        innerImage.source
    property alias  contentWidth:       innerText.contentWidth

    property bool forceImageScale11: false
    property real imageScale:        forceImageScale11 && (text == "") ? 0.8 : 0.6
    property real contentMargins:    innerText.height * 0.1

    property color _currentContentColor:  (checked || pressed) ? qgcPal.buttonHighlightText : qgcPal.buttonText
    property color _currentContentColorSecondary:  (checked || pressed) ? qgcPal.buttonText : qgcPal.buttonHighlight

    signal dropped(int index)

    onCheckedChanged: toolStripAction.checked = checked

    onClicked: {
        if (mainWindow.allowViewSwitch()) {
            dropPanel.hide()
            if (!toolStripAction.dropPanelComponent) {
                toolStripAction.triggered(this)
            } else if (checked) {
                var panelEdgeTopPoint = mapToItem(_root, width, 0)
                dropPanel.show(panelEdgeTopPoint, toolStripAction.dropPanelComponent, this)
                checked = true
                control.dropped(index)
            }
        } else if (checkable) {
            checked = !checked
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        id:                 contentLayoutItem
        anchors.fill:       parent
        anchors.margins:    contentMargins

        Column {
            anchors.centerIn:   parent
            spacing:        contentMargins * 2

            Image {
                id:                         innerImageColorful
                height:                     contentLayoutItem.height * 0.3
                width:                      contentLayoutItem.width  * 0.3
                smooth:                     true
                mipmap:                     true
                fillMode:                   Image.PreserveAspectFit
                antialiasing:               true
                sourceSize.height:          height
                sourceSize.width:           width
                anchors.horizontalCenter:   parent.horizontalCenter
                source:                     control.imageSource
                visible:                    source != "" && modelData.fullColorIcon
            }

            QGCColoredImage {
                id:                         innerImage
                height:                     contentLayoutItem.height * 0.3
                width:                      contentLayoutItem.width  * 0.3
                smooth:                     true
                mipmap:                     true
                color:                      _currentContentColor

                fillMode:                   Image.PreserveAspectFit
                antialiasing:               true
                sourceSize.height:          height
                sourceSize.width:           width
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    source != "" && !modelData.fullColorIcon
                
                QGCColoredImage {
                    id:                         innerImageSecondColor
                    source:                     modelData.alternateIconSource
                    height:                     contentLayoutItem.height * 0.3
                    width:                      contentLayoutItem.width  * 0.3
                    smooth:                     true
                    mipmap:                     true
                    color:                      _currentContentColorSecondary
                    fillMode:                   Image.PreserveAspectFit
                    antialiasing:               true
                    sourceSize.height:          height
                    sourceSize.width:           width
                    anchors.horizontalCenter:   parent.horizontalCenter
                    visible:                    source != "" && modelData.biColorIcon
                }
            }

            QGCLabel {
                id:                         innerText
                text:                       control.text
                // color:                      _currentContentColor
                color:                      "black"
                anchors.horizontalCenter:   parent.horizontalCenter
                font.bold:                  !innerImage.visible && !innerImageColorful.visible
                font.pointSize: ScreenTools.smallFontPointSize * 1.2   // ⬅ 放大字体 30%
                opacity:                    !innerImage.visible ? 0.8 : 1.0
            }
        }
    }

    background: Rectangle {
        id: buttonBkRect
        width:  innerImage.width * 2.5      // 圆的大小略大于图标
        height: width                       // 保持正圆
        radius: width / 2                   // 圆形
        anchors.centerIn: parent            // 居中放置

        color: (control.checked || control.pressed)
            ? qgcPal.buttonHighlight
            : ((control.enabled && control.hovered)
                ? qgcPal.toolStripHoverColor
                : Qt.rgba(0, 0, 0, 0.4))    // 默认浅灰半透明

        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.4)
        visible: innerImage.visible || innerImageColorful.visible
    }


    // background: Rectangle {
    //     id: buttonBkRect
    //     color: (control.checked || control.pressed) ?
    //         qgcPal.buttonHighlight :
    //         ((control.enabled && control.hovered) ?
    //             qgcPal.toolStripHoverColor :
    //             Qt.rgba(0, 0, 0, 0.5))   // 默认透明
    //     anchors.fill: parent
    // }

    // background: Rectangle {
    //     id:             buttonBkRect
    //     color:          (control.checked || control.pressed) ?
    //                         qgcPal.buttonHighlight :
    //                         ((control.enabled && control.hovered) ? qgcPal.toolStripHoverColor : qgcPal.toolbarBackground)
    //     anchors.fill:   parent
    // }
}
