/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controllers
import QGroundControl.Palette

QGCPopupDialog {
    id:         root
    title:      qsTr("仪表盘设置")
    buttons:    Dialog.Close

    property var instrumentValueData

    QGCPalette { id: qgcPal;        colorGroupEnabled: parent.enabled }
    QGCPalette { id: qgcPalDisable; colorGroupEnabled: false }

    Loader {
        sourceComponent: instrumentValueData.fact ? editorComponent : noFactComponent
    }

    Component {
        id: noFactComponent

        QGCLabel {
            text: qsTr("仪表盘显示需要连接设备。")
        }
    }

    Component {
        id: editorComponent
        ColumnLayout {
            spacing: 4

            property var factValueEnglish: [
                "roll", "pitch", "heading", "groundSpeed",
                "altitudeRelative", "altitudeAMSL","flightTime",
                "flightDistance", "distanceToHome", "climbRate",
                "lon", "lat"
            ]
            property var factValueChinese: [
                "横滚角", "俯仰角", "航向", "飞行速度",
                "相对高度", "海拔高度","飞行时间",
                "飞行路程", "距家距离", "升降速度",
                "经度", "纬度"
            ]

            property var checkedFlags: Array(factValueEnglish.length).fill(false)
            property var additionalFacts: []

            Column {
                spacing: 4

                Repeater {
                    model: factValueChinese.length

                    CheckBox {
                        text: factValueChinese[index]
                        checked: checkedFlags[index]

                        onCheckedChanged: {
                            checkedFlags[index] = checked

                            if (!factValueGrid) return

                            let factName = factValueEnglish[index]
                            let groupName = "vehicle"  // 默认 FactGroup，如果有下拉可以改为选中的 group
                            // 如果是经纬度，改为 gps group
                            if (factName === "lon" || factName === "lat") {
                                groupName = "gps"
                            }
                            if (checked) {
                                if (additionalFacts.indexOf(factName) === -1) {
                                    additionalFacts.push(factName)

                                    // appendFact 返回新建的 InstrumentValueData
                                    let newValue = factValueGrid.appendFact(factName)
                                    if (newValue) {
                                        newValue.setFact(groupName, factName)      // 绑定 Fact
                                        newValue.text = factValueChinese[index]    // 中文显示
                                    }
                                }
                            } else {
                                let idx = additionalFacts.indexOf(factName)
                                if (idx !== -1) {
                                    additionalFacts.splice(idx, 1)
                                    factValueGrid.removeFact(factName)
                                }
                            }
                        }
                    }
                }
            }

            Connections {
                target: factValueGrid
                onFactsChanged: {
                    for (let i = 0; i < factValueEnglish.length; i++) {
                        checkedFlags[i] = factValueGrid.facts.indexOf(factValueEnglish[i]) !== -1
                    }
                    additionalFacts = factValueGrid.facts.slice()

                    saveCheckedFlags()  // 每次仪表盘更新时同步保存
                }
            }
        }
    }




        // RowLayout {
        //     visible:false
        //     spacing: ScreenTools.defaultFontPixelWidth
        //
        //     ColumnLayout {
        //         spacing: ScreenTools.defaultFontPixelHeight / 2
        //
        //         SettingsGroupLayout {
        //             heading: qsTr("仪表盘")
        //             LabelledComboBox {
        //                 id: factGroupCombo
        //                 label: qsTr("类型")
        //
        //                 // 显示中文，但逻辑使用英文
        //                 property var groupEnglishNames: ["Vehicle", "Gps"]
        //                 property var groupChineseNames: ["飞行器", "卫星定位"]
        //
        //                 model: groupChineseNames
        //                 currentIndex: groupEnglishNames.indexOf(instrumentValueData.factGroupName)
        //
        //                 onActivated: (index) => {
        //                     let groupName = groupEnglishNames[index] // 英文名字
        //                     instrumentValueData.setFact(groupName, "")
        //                     instrumentValueData.icon = ""
        //                     instrumentValueData.text = instrumentValueData.fact ? instrumentValueData.fact.shortDescription : qsTr("标签")
        //
        //                     // 更新 Fact Value 下拉
        //                     factNamesCombo.updateModel()
        //                 }
        //
        //                 Connections {
        //                     target: instrumentValueData
        //                     onFactGroupNameChanged: factGroupCombo.currentIndex = groupEnglishNames.indexOf(instrumentValueData.factGroupName)
        //                 }
        //             }
        //
        //             // --- Fact Value 下拉 ---
        //             LabelledComboBox {
        //                 id: factNamesCombo
        //                 label: qsTr("参数")
        //                 property var factValueEnglish: []
        //                 property var factValueChinese: []
        //
        //                 function updateModel() {
        //                     let groupName = factGroupCombo.groupEnglishNames[factGroupCombo.currentIndex]
        //
        //                     if (groupName === "Vehicle") {
        //                         factValueEnglish = ["Roll", "Pitch", "Heading", "GroundSpeed","AltitudeRelative", "AltitudeAMSL","throttlePct","flightDistance","distanceToHome","climbRate"]
        //                         factValueChinese = ["横滚角", "俯仰角", "航向", "飞行速度","相对高度", "海拔高度","油门比例","飞行路程","距家距离","上升下降速度"]
        //                     } else if (groupName === "Gps") {
        //                         factValueEnglish = ["Lon","Lat"]
        //                         factValueChinese = ["经度","纬度"]
        //                     }
        //
        //                     model = factValueChinese           // 中文显示
        //                     currentIndex = 0
        //
        //                     // 默认选择第一个 Fact
        //                     instrumentValueData.setFact(groupName, factValueEnglish[0])
        //                     instrumentValueData.icon = ""
        //                     instrumentValueData.text = factValueChinese[0]   // 默认中文显示
        //                 }
        //
        //                 Component.onCompleted: updateModel()
        //
        //                 onActivated: (index) => {
        //                     let groupName = factGroupCombo.groupEnglishNames[factGroupCombo.currentIndex]
        //                     let factName = factValueEnglish[index]
        //                     instrumentValueData.setFact(groupName, factName)      // 通信用英文
        //                     instrumentValueData.icon = ""
        //                     instrumentValueData.text = factValueChinese[index]   // 显示中文
        //                 }
        //
        //                 Connections {
        //                     target: instrumentValueData
        //                     onFactNameChanged: factNamesCombo.currentIndex = factValueEnglish.indexOf(instrumentValueData.factName)
        //                 }
        //             }
        //         }
        //         //     LabelledComboBox {
        //         //         id:                     factGroupCombo
        //         //         label:                  qsTr("组")
        //         //         model:                  instrumentValueData.factGroupNames
        //         //         currentIndex:           instrumentValueData.factGroupNames.indexOf(instrumentValueData.factGroupName)
        //         //         onActivated: (index) => {
        //         //             instrumentValueData.setFact(currentText, "")
        //         //             instrumentValueData.icon = ""
        //         //             instrumentValueData.text = instrumentValueData.fact.shortDescription
        //         //         }
        //         //         Connections {
        //         //             target: instrumentValueData
        //         //             onFactGroupNameChanged: factGroupCombo.currentIndex = factGroupCombo.comboBox.find(instrumentValueData.factGroupName)
        //         //         }
        //         //     }
        //         //
        //         //     LabelledComboBox {
        //         //         id:                     factNamesCombo
        //         //         label:                  qsTr("值")
        //         //         model:                  instrumentValueData.factValueNames
        //         //
        //         //         model: instrumentValueData.factValueNames
        //         //         currentIndex:           instrumentValueData.factValueNames.indexOf(instrumentValueData.factName)
        //         //         onActivated: (index) => {
        //         //             instrumentValueData.setFact(instrumentValueData.factGroupName, currentText)
        //         //             instrumentValueData.icon = ""
        //         //             instrumentValueData.text = instrumentValueData.fact.shortDescription
        //         //         }
        //         //         Connections {
        //         //             target: instrumentValueData
        //         //             onFactNameChanged: factNamesCombo.currentIndex = factNamesCombo.comboBox.find(instrumentValueData.factName)
        //         //         }
        //         //     }
        //         // }
        //
        //         SettingsGroupLayout {
        //             heading: qsTr("标签")
        //             visible:false
        //
        //             ColumnLayout {
        //                 Layout.fillWidth:   true
        //                 spacing:            ScreenTools.defaultFontPixelHeight / 2
        //
        //                 RowLayout {
        //
        //                     Layout.fillWidth:  true
        //                     visible:false
        //
        //                     QGCRadioButton {
        //                         id:                     iconRadio
        //                         text:                   qsTr("图标")
        //                         Layout.fillWidth:       true
        //                         Component.onCompleted:  checked = instrumentValueData.icon != ""
        //                         onClicked: {
        //                             instrumentValueData.text = ""
        //                             instrumentValueData.icon = instrumentValueData.factValueGrid.iconNames[0]
        //                         }
        //                         ButtonGroup.group:      labelTypeGroup
        //                         ButtonGroup { id: labelTypeGroup }
        //                     }
        //
        //                     RowLayout {
        //                         id:         iconOptionInputs
        //                         Rectangle {
        //                             width:      height
        //                             height:     changeIconBtn.height
        //                             color:      qgcPal.windowShade
        //                             opacity:    iconRadio.checked ? 1 : .3
        //
        //                             QGCColoredImage {
        //                                 id:                 valueIcon
        //                                 anchors.centerIn:   parent
        //                                 height:             ScreenTools.defaultFontPixelHeight
        //                                 width:              height
        //                                 source:             "/InstrumentValueIcons/" + (instrumentValueData.icon ? instrumentValueData.icon : instrumentValueData.factValueGrid.iconNames[0])
        //                                 sourceSize.height:  height
        //                                 fillMode:           Image.PreserveAspectFit
        //                                 mipmap:             true
        //                                 smooth:             true
        //                                 color:              valueIcon.status === Image.Error ? "red" : qgcPal.text
        //                             }
        //                         }
        //                         QGCButton {
        //                             id:         changeIconBtn
        //                             text:       qsTr("切换图标")
        //                             enabled:    iconRadio.checked
        //                             onClicked: {
        //                                 var updateFunction = function(icon){ instrumentValueData.icon = icon }
        //                                 iconPickerDialog.createObject(mainWindow, { iconNames: instrumentValueData.factValueGrid.iconNames, icon: instrumentValueData.icon, updateIconFunction: updateFunction }).open()
        //                             }
        //                         }
        //                     }
        //                 }
        //
        //                 RowLayout {
        //                     Layout.fillWidth: true
        //                     visible:false
        //
        //                     QGCRadioButton {
        //                         id: textRadio
        //                         text: qsTr("文本")
        //                         Layout.fillWidth: true
        //                         Component.onCompleted: checked = instrumentValueData.icon == ""
        //
        //                         onClicked: {
        //                             instrumentValueData.icon = ""
        //                             // 获取中文名称
        //                             let index = factNamesCombo.factValueEnglish.indexOf(instrumentValueData.factName)
        //                             instrumentValueData.text = index >= 0 ? factNamesCombo.factValueChinese[index] : qsTr("标签")
        //                         }
        //                     }
        //
        //                     QGCTextField {
        //                         enabled: textRadio.checked
        //                         Layout.minimumWidth: 200
        //                         text: {
        //                             if (textRadio.checked) {
        //                                 // 中文显示
        //                                 let index = factNamesCombo.factValueEnglish.indexOf(instrumentValueData.factName)
        //                                     index >= 0 ? factNamesCombo.factValueChinese[index] : instrumentValueData.text
        //                             } else {
        //                                 // 不显示时仍显示默认
        //                                 instrumentValueData.text
        //                             }
        //                         }
        //                         onEditingFinished: instrumentValueData.text = text
        //                     }
        //                 }
        //                 // RowLayout {
        //                 //     Layout.fillWidth: true
        //                 //     QGCRadioButton {
        //                 //         id:                     textRadio
        //                 //         text:                   qsTr("文本")
        //                 //         Layout.fillWidth:       true
        //                 //         ButtonGroup.group:      labelTypeGroup
        //                 //         Component.onCompleted:  checked = instrumentValueData.icon == ""
        //                 //         onClicked: {
        //                 //             instrumentValueData.icon = ""
        //                 //             instrumentValueData.text = instrumentValueData.fact ? instrumentValueData.fact.shortDescription : qsTr("标签")
        //                 //         }
        //                 //     }
        //                 //
        //                 //     QGCTextField {
        //                 //         enabled:                textRadio.checked
        //                 //         Layout.minimumWidth:    iconOptionInputs.width
        //                 //         text:                   textRadio.checked
        //                 //                                     ? instrumentValueData.text
        //                 //                                     : instrumentValueData.fact ? instrumentValueData.fact.shortDescription : qsTr("标签")
        //                 //         onEditingFinished:      instrumentValueData.text = text
        //                 //     }
        //                 // }
        //             }
        //
        //             // LabelledComboBox {
        //             //     label:          qsTr("大小")
        //             //     model:          instrumentValueData.factValueGrid.fontSizeNames
        //             //     currentIndex:   instrumentValueData.factValueGrid.fontSize
        //             //     onActivated:    (index) => { instrumentValueData.factValueGrid.fontSize = index }
        //             // }
        //             LabelledComboBox {
        //                 visible: false   // 隐藏
        //                 enabled: false   // 禁止交互
        //                 label:          qsTr("大小")
        //                 model:          instrumentValueData.factValueGrid.fontSizeNames
        //                 currentIndex:   instrumentValueData.factValueGrid.fontSize
        //                 onActivated:    (index) => { instrumentValueData.factValueGrid.fontSize = index }
        //             }
        //
        //             Component.onCompleted: {
        //                 instrumentValueData.factValueGrid.fontSize = 3  // 设置默认值
        //             }
        //
        //             QGCCheckBoxSlider {
        //                 Layout.fillWidth: true
        //                 text:       qsTr("显示单位")
        //                 checked:    false
        //                 //checked:    instrumentValueData.showUnits
        //                 visible:    false
        //                 onClicked:  instrumentValueData.showUnits = checked
        //             }
        //         }
        //     }
        //
        //     SettingsGroupLayout {
        //         Layout.alignment:   Qt.AlignTop
        //         heading:            qsTr("范围")
        //         visible:            false
        //
        //         ColumnLayout {
        //             Layout.fillWidth: true
        //
        //             RowLayout {
        //                 Layout.fillWidth:   true
        //                 spacing:            ScreenTools.defaultFontPixelWidth * 2
        //
        //                 QGCLabel {
        //                     Layout.fillWidth:       true
        //                     text:                   qsTr("类型")
        //                 }
        //
        //                 QGCComboBox {
        //                     id:                 rangeTypeCombo
        //                     model:              instrumentValueData.rangeTypeNames
        //                     currentIndex:       instrumentValueData.rangeType
        //                     sizeToContents:     true
        //                     onActivated: (index) => { instrumentValueData.rangeType = index }
        //                 }
        //             }
        //
        //             Loader {
        //                 id:                     rangeLoader
        //                 visible:                sourceComponent
        //                 Layout.columnSpan:      2
        //                 Layout.alignment:       Qt.AlignHCenter
        //                 Layout.margins:         ScreenTools.defaultFontPixelWidth
        //                 Layout.preferredWidth:  item ? item.width : 0
        //                 Layout.preferredHeight: item ? item.height : 0
        //
        //                 property var instrumentValueData: root.instrumentValueData
        //
        //                 function updateSourceComponent() {
        //                     switch (instrumentValueData.rangeType) {
        //                     case InstrumentValueData.NoRangeInfo:
        //                         sourceComponent = undefined
        //                         break
        //                     case InstrumentValueData.ColorRange:
        //                         sourceComponent = colorRangeDialog
        //                         break
        //                     case InstrumentValueData.OpacityRange:
        //                         sourceComponent = opacityRangeDialog
        //                         break
        //                     case InstrumentValueData.IconSelectRange:
        //                         sourceComponent = iconRangeDialog
        //                         break
        //                     }
        //                 }
        //
        //                 Component.onCompleted: {
        //                     updateSourceComponent()
        //                     if (sourceComponent) {
        //                         height = item.childrenRect.height
        //                         width = item.childrenRect.width
        //                     }
        //                 }
        //
        //                 Connections {
        //                     target:             instrumentValueData
        //                     onRangeTypeChanged: rangeLoader.updateSourceComponent()
        //                 }
        //             }
        //         }
        //     }
        // }
    // }

    Component {
        id: colorRangeDialog

        Item {
            width:  childrenRect.width
            height: childrenRect.height

            function updateRangeValue(index, text) {
                var newValues = instrumentValueData.rangeValues
                newValues[index] = parseFloat(text)
                instrumentValueData.rangeValues = newValues
            }

            function updateColorValue(index, color) {
                var newColors = instrumentValueData.rangeColors
                newColors[index] = color
                instrumentValueData.rangeColors = newColors
            }

            ColorDialog {
                id:             colorPickerDialog
                modality:       Qt.ApplicationModal
                selectedColor:  instrumentValueData.rangeColors.length ? instrumentValueData.rangeColors[colorIndex] : "white"
                onAccepted:     updateColorValue(colorIndex, color)

                property int colorIndex: 0
            }

            Column {
                id:         mainColumn
                spacing:    ScreenTools.defaultFontPixelHeight / 2

                QGCLabel {
                    width:      rowLayout.width
                    text:       qsTr("指定值范围对应的颜色。如果图标可用，则应用图标颜色，否则应用值本身的颜色。")
                    wrapMode:   Text.WordWrap
                }

                Row {
                    id:         rowLayout
                    spacing:    _margins

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _margins

                        Repeater {
                            model: instrumentValueData.rangeValues.length

                            QGCColoredImage {
                                width:      ScreenTools.implicitTextFieldHeight
                                height:     width
                                fillMode:   Image.PreserveAspectFit
                                color:      QGroundControl.globalPalette.text
                                source:     "/res/TrashDelete.svg"

                                QGCMouseArea {
                                    fillItem:   parent
                                    onClicked:  instrumentValueData.removeRangeValue(index)
                                }
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _margins

                        Repeater {
                            model: instrumentValueData.rangeValues.length

                            QGCTextField {
                                text:               instrumentValueData.rangeValues[index]
                                onEditingFinished:  updateRangeValue(index, text)
                            }
                        }
                    }

                    Column {
                        spacing: _margins
                        Repeater {
                            model: instrumentValueData.rangeColors

                            QGCCheckBox {
                                height:     ScreenTools.implicitTextFieldHeight
                                checked:    instrumentValueData.isValidColor(instrumentValueData.rangeColors[index])
                                onClicked:  updateColorValue(index, checked ? "green" : instrumentValueData.invalidColor())
                            }
                        }
                    }

                    Column {
                        spacing: _margins
                        Repeater {
                            model: instrumentValueData.rangeColors

                            Rectangle {
                                width:          ScreenTools.implicitTextFieldHeight
                                height:         width
                                border.color:   qgcPal.text
                                color:          instrumentValueData.isValidColor(modelData) ? modelData : qgcPal.text

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        colorPickerDialog.colorIndex = index
                                        colorPickerDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }

                QGCButton {
                    text:       qsTr("添加行")
                    onClicked:  instrumentValueData.addRangeValue()
                }
            }
        }
    }

    Component {
        id: iconRangeDialog

        Item {
            width:  childrenRect.width
            height: childrenRect.height

            function updateRangeValue(index, text) {
                var newValues = instrumentValueData.rangeValues
                newValues[index] = parseFloat(text)
                instrumentValueData.rangeValues = newValues
            }

            function updateIconValue(index, icon) {
                var newIcons = instrumentValueData.rangeIcons
                newIcons[index] = icon
                instrumentValueData.rangeIcons = newIcons
            }

            Column {
                id:         mainColumn
                spacing:    ScreenTools.defaultFontPixelHeight / 2

                QGCLabel {
                    width:      rowLayout.width
                    text:       qsTr("指定值范围对应的图标。")
                    wrapMode:   Text.WordWrap
                }

                Row {
                    id:         rowLayout
                    spacing:    _margins

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _margins

                        Repeater {
                            model: instrumentValueData.rangeValues.length

                            QGCColoredImage {
                                width:      ScreenTools.implicitTextFieldHeight
                                height:     width
                                fillMode:   Image.PreserveAspectFit
                                color:      QGroundControl.globalPalette.text
                                source:     "/res/TrashDelete.svg"

                                QGCMouseArea {
                                    fillItem:   parent
                                    onClicked:  instrumentValueData.removeRangeValue(index)
                                }
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _margins

                        Repeater {
                            model: instrumentValueData.rangeValues.length

                            QGCTextField {
                                text:               instrumentValueData.rangeValues[index]
                                onEditingFinished:  updateRangeValue(index, text)
                            }
                        }
                    }

                    Column {
                        spacing: _margins

                        Repeater {
                            model: instrumentValueData.rangeIcons

                            QGCColoredImage {
                                height:             ScreenTools.implicitTextFieldHeight
                                width:              height
                                source:             "/InstrumentValueIcons/" + modelData
                                sourceSize.height:  height
                                fillMode:           Image.PreserveAspectFit
                                mipmap:             true
                                smooth:             true
                                color:              qgcPal.text

                                MouseArea {
                                    anchors.fill:   parent
                                    onClicked: {
                                        var updateFunction = function(icon){ updateIconValue(index, icon) }
                                        iconPickerDialog.createObject(mainWindow, { iconNames: instrumentValueData.factValueGrid.iconNames, icon: modelData, updateIconFunction: updateFunction }).open()
                                    }
                                }
                            }
                        }
                    }
                }

                QGCButton {
                    text:       qsTr("添加行")
                    onClicked:  instrumentValueData.addRangeValue()
                }
            }
        }
    }

    Component {
        id: opacityRangeDialog

        Item {
            width:  childrenRect.width
            height: childrenRect.height

            function updateRangeValue(index, text) {
                var newValues = instrumentValueData.rangeValues
                newValues[index] = parseFloat(text)
                instrumentValueData.rangeValues = newValues
            }

            function updateOpacityValue(index, opacity) {
                var newOpacities = instrumentValueData.rangeOpacities
                newOpacities[index] = opacity
                instrumentValueData.rangeOpacities = newOpacities
            }

            Column {
                id:         mainColumn
                spacing:    ScreenTools.defaultFontPixelHeight / 2

                QGCLabel {
                    width:      rowLayout.width
                    text:       qsTr("指定值范围对应的图标透明度。")
                    wrapMode:   Text.WordWrap
                }

                Row {
                    id:         rowLayout
                    spacing:    _margins

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _margins

                        Repeater {
                            model: instrumentValueData.rangeValues.length

                            QGCColoredImage {
                                width:      ScreenTools.implicitTextFieldHeight
                                height:     width
                                fillMode:   Image.PreserveAspectFit
                                color:      QGroundControl.globalPalette.text
                                source:     "/res/TrashDelete.svg"

                                QGCMouseArea {
                                    fillItem:   parent
                                    onClicked:  instrumentValueData.removeRangeValue(index)
                                }
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _margins

                        Repeater {
                            model: instrumentValueData.rangeValues

                            QGCTextField {
                                text:               modelData
                                onEditingFinished:  updateRangeValue(index, text)
                            }
                        }
                    }

                    Column {
                        spacing: _margins

                        Repeater {
                            model: instrumentValueData.rangeOpacities

                            QGCTextField {
                                text:               modelData
                                onEditingFinished:  updateOpacityValue(index, text)
                            }
                        }
                    }
                }

                QGCButton {
                    text:       qsTr("添加行")
                    onClicked:  instrumentValueData.addRangeValue()
                }
            }
        }
    }

    Component {
        id: iconPickerDialog

        QGCPopupDialog {
            title:      qsTr("选择图标")
            buttons:    Dialog.Close

            property var     iconNames
            property string  icon
            property var     updateIconFunction

            GridLayout {
                columns:        10
                columnSpacing:  0
                rowSpacing:     0

                Repeater {
                    model: iconNames

                    Rectangle {
                        height: ScreenTools.minTouchPixels
                        width:  height
                        color:  currentSelection ? qgcPal.text  : qgcPal.window

                        property bool currentSelection: icon == modelData

                        QGCColoredImage {
                            anchors.centerIn:   parent
                            height:             parent.height * 0.75
                            width:              height
                            source:             "/InstrumentValueIcons/" + modelData
                            sourceSize.height:  height
                            fillMode:           Image.PreserveAspectFit
                            mipmap:             true
                            smooth:             true
                            color:              currentSelection ? qgcPal.window : qgcPal.text

                            MouseArea {
                                anchors.fill:   parent
                                onClicked:  {
                                    icon = modelData
                                    updateIconFunction(modelData)
                                    close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
