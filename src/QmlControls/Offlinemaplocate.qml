/****************************************************************************
 *
 * LocateButton.qml
 *
 * QGroundControl 模块化悬浮定位按钮
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Palette
import QGroundControl.ScreenTools

QGCToolBarButton {
    id: locateButton
    width: 48
    height: 48
    icon.source: "/res/locate.svg"
    logo: true

    // 悬浮位置，可通过外部 anchors 调整
    property Item target: null      // 外部传入需要对齐的控件
    property int  offsetY: 8        // 垂直间距

    anchors.horizontalCenter: target ? target.horizontalCenter : undefined
    anchors.bottom: target ? target.top : undefined
    anchors.margins: offsetY

    onClicked: {
        var gcsPos = QGCPositionManager.instance().gcsPosition
        if (!gcsPos.isValid()) {
            mainWindow.showMessageDialog(qsTr("提示"), qsTr("当前定位不可用"))
            return
        }
        if (flyView && flyView.map) {
            flyView.map.center = gcsPos
            flyView.map.zoomLevel = 18
        }
    }
}
