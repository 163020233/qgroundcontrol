/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

// Custom builds can override this file to add custom guided actions.

import QtQml

QtObject {
    readonly property int actionCustomButton: _guidedController.customActionStart + 0

    readonly property string customButtonTitle: qsTr("默认")

    readonly property string customButtonMessage: qsTr("自定义操作示例")

    function customConfirmAction(actionCode, actionData, mapIndicator, confirmDialog) {
        switch (actionCode) {
        case actionCustomButton:
            confirmDialog.hideTrigger = true
            confirmDialog.title = customButtonTitle
            confirmDialog.message = customButtonMessage
            break
        default:
            return false // false = action not handled here
        }

        return true // true = action handled here
    }

    function customExecuteAction(actionCode, actionData, sliderOutputValue, optionCheckedode) {
        switch (actionCode) {
        case actionCustomButton:
            mainWindow.showMessageDialog("自定义操作", "已执行自定义操作")
            break
        default:
            return false // false = action not handled here
        }

        return true // true = action handled here
    }
}