/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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
    id:         root
    spacing:    _rowSpacing

    // --- 1. 标准属性定义 (QGC 惯例) ---
    // 这些变量名是 QGC 源码中通用的，保持一致可以让布局统一
    property real _rowSpacing:          ScreenTools.defaultFontPixelHeight * 0.5
    property real _colSpacing:          ScreenTools.defaultFontPixelWidth * 2
    property real _labelWidth:          ScreenTools.defaultFontPixelWidth * 16
    property real _secondColumnWidth:   ScreenTools.defaultFontPixelWidth * 20

    // QGC 调色板 (用于适配深色/浅色模式)
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // --- 2. 保存逻辑 ---
    // 当用户在该页面修改设置或点击“连接”时，LinkManager 可能会调用此函数
    // 哪怕现在是空的，也要留着占位，防止 C++ 调用报错
    function saveSettings() {
        // 示例：如果以后有配置项，在这里处理额外逻辑
        // subEditConfig.enableLog = logCheckBox.checked
    }

    // --- 3. 界面主体 ---

    // 标题区域
    QGCLabel {
        text:           qsTr("Boying SDK 连接配置")
        font.pointSize: ScreenTools.mediumFontPointSize
        font.bold:      true
    }

    Item { height: _rowSpacing; width: 1 } // 占位间距

    // 配置网格 (模仿 SerialSettings 的 GridLayout)
    GridLayout {
        columns:        2
        rowSpacing:     _rowSpacing
        columnSpacing:  _colSpacing

        // --- 行 1: 连接模式 ---
        QGCLabel { text: qsTr("连接模式") }
        QGCLabel {
            Layout.preferredWidth:  _secondColumnWidth
            text:                   qsTr("内部集成 (Internal Link)")
            color:                  qgcPal.textHighlight // 使用高亮色强调
            font.bold:              true
        }

        // --- 行 2: 协议版本 ---
        QGCLabel { text: qsTr("MAVLink 协议") }
        QGCLabel {
            text:                   "v2.0"
            color:                  qgcPal.text
        }

        // --- 行 3: 可选配置 (示例：是否高延迟模式) ---
        // 这里的 subEditConfig 就是 C++ 里的 BoyingLinkConfiguration 对象
        // 只要你在 C++ 里用了 Q_PROPERTY，这里就能直接读写
        QGCLabel { text: qsTr("连接选项") }
        QGCCheckBox {
            id:                 highLatencyCheck
            text:               qsTr("高延迟模式 (High Latency)")
            // 绑定 C++ 属性 (假设你有这个属性，没有这就删掉)
            checked:            subEditConfig ? subEditConfig.highLatency : false
            onClicked: {
                if (subEditConfig) {
                    subEditConfig.highLatency = checked
                }
            }
        }
    }

    // --- 分割线 ---
    Rectangle {
        Layout.fillWidth:   true
        Layout.topMargin:   ScreenTools.defaultFontPixelHeight
        Layout.bottomMargin:ScreenTools.defaultFontPixelHeight
        height:             1
        color:              qgcPal.text
        opacity:            0.2
    }

    // --- 说明区域 (类似 SerialSettings 的高级设置风格) ---
    QGCLabel {
        text: qsTr("SDK 信息")
        font.bold: true
    }

    Rectangle {
        Layout.fillWidth:       true
        Layout.preferredHeight: infoCol.height + (_rowSpacing * 2)
        color:                  qgcPal.windowShade // 使用 QGC 标准底色
        radius:                 ScreenTools.defaultFontPixelHeight * 0.25

        ColumnLayout {
            id:                 infoCol
            anchors.centerIn:   parent
            width:              parent.width - (_colSpacing * 2)
            spacing:            _rowSpacing

            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                text:               qsTr("此连接直接加载厂商提供的 Android 本地库 (.so)。")
            }

            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                font.pointSize:     ScreenTools.smallFontPointSize
                text:               qsTr("注意：\n1. 请确保遥控器已开启 USB 调试或 OTG 权限。\n2. SDK 将自动接管串口通信，无需手动配置波特率。")
                color:              qgcPal.text // 或者用 qgcPal.warningText
            }
        }
    }

    // 底部弹簧 (把内容顶到最上面)
    Item { Layout.fillHeight: true; width: 1 }
}