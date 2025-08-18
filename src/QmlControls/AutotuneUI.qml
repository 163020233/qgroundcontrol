/****************************************************************************
 *
 * (c) 2009-2021 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controllers
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

ColumnLayout {
    spacing: ScreenTools.defaultFontPixelHeight

    property var  _activeVehicle:   globals.activeVehicle
    property var  _autotuneManager: _activeVehicle.autotune
    property real _margins:         ScreenTools.defaultFontPixelHeight

    QGCButton {
        id:        autotuneButton
        primary:   true
        text:      qsTr("开始自动调参")
        enabled:   _activeVehicle.flying && !_activeVehicle.landing && !_autotuneManager.autotuneInProgress

        onClicked: mainWindow.showMessageDialog(autotuneButton.text,
                                                qsTr("警告!\
        \n\n自动调参过程应该谨慎执行，要求飞行器在执行过程中保持稳定。\
        \n\n在开始自动调参过程之前，请确保您已经阅读了自动调参指南并按照初步步骤进行了操作。\
        \n\n在开始自动调参过程之前，请确保您已经阅读了自动调参指南并按照初步步骤进行了操作。\
        \n1. 您已经阅读了自动调参指南并按照初步步骤进行了操作 \
        \n2. 当前的控制增益足够好，能够在存在中 medium 扰动的情况下稳定飞行器 \
        \n3. 您已经准备好在任何时候通过移动 RC 摇杆来中止自动调参过程。\
        \n\n点击 Ok 开始自动调参过程。\n"),
                                                Dialog.Ok | Dialog.Cancel,
                                                function() { _autotuneManager.autotuneRequest() })
    }

    QGCLabel { text: _autotuneManager.autotuneStatus }

    ProgressBar {
        value: _autotuneManager.autotuneProgress
    }
}
