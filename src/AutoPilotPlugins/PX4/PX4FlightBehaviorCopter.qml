/****************************************************************************
 *
 * (c) 2021 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactSystem
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.ScreenTools

SetupPage {
    id:             flightBehavior
    pageComponent:  pageComponent
    property real _margins: ScreenTools.defaultFontPixelHeight

    FactPanelController {
        id:         controller
    }

    QGCPalette {
        id:                 qgcPal
    }

    property Fact _sys_vehicle_resp:  controller.getParameterFact(-1, "SYS_VEHICLE_RESP", false)
    property Fact _mpc_xy_vel_all:    controller.getParameterFact(-1, "MPC_XY_VEL_ALL", false)
    property Fact _mpc_z_vel_all:     controller.getParameterFact(-1, "MPC_Z_VEL_ALL", false)

    Component {
        id: pageComponent

        Column {

            spacing:            _margins

            Column {
                visible:                _sys_vehicle_resp

                QGCCheckBox {
                    id:                 responsivenessCheckbox
                    text:               qsTr("启用响应滑块（如果启用，则会自动设置加速度限制参数和其他参数）")
                    checked:            _sys_vehicle_resp && _sys_vehicle_resp.value >= 0
                    onClicked: {
                        if (checked) {
                            _sys_vehicle_resp.value = Math.abs(_sys_vehicle_resp.value)
                        } else {
                            _sys_vehicle_resp.value = -Math.abs(_sys_vehicle_resp.value)
                        }
                    }
                }

                FactSliderPanel {
                    width:          availableWidth
                    enabled:        responsivenessCheckbox.checked

                    sliderModel: ListModel {
                        id:             responsivenessSlider

                        ListElement {
                            title:          qsTr("响应度")
                            description:    qsTr("较高的值会使设备更快地响应。请注意，这也会影响制动，因此响应度与最大速度的组合会导致较长的制动距离。")
                            param:          "SYS_VEHICLE_RESP"
                            min:            0.01
                            max:            1
                            step:           0.01
                        }
                    }
                }
                QGCLabel {
                    visible:            _sys_vehicle_resp && _sys_vehicle_resp.value > 0.8
                    color:              qgcPal.warningText
                    text:              qsTr("警告：较高的响应度要求设备具有较大的推力到重量比。否则，车辆可能会失去高度。")
                }
            }

            Column {
                visible:                _mpc_xy_vel_all

                QGCCheckBox {
                    id:                 xyVelCheckbox
                    text:               qsTr("启用水平速度滑块（如果启用，则会自动设置个体速度限制参数）")
                    checked:            _mpc_xy_vel_all ? (_mpc_xy_vel_all.value >= 0) : false
                    onClicked: {
                        if (checked) {
                            _mpc_xy_vel_all.value = Math.abs(_mpc_xy_vel_all.value)
                        } else {
                            _mpc_xy_vel_all.value = -Math.abs(_mpc_xy_vel_all.value)
                        }
                    }
                }

                FactSliderPanel {
                    width:          availableWidth
                    enabled:        xyVelCheckbox.checked

                    sliderModel: ListModel {
                        id:             xyVelSlider

                        ListElement {
                            title:          qsTr("水平速度（m/s）")
                            description:    qsTr("限制水平速度（适用于所有模式）。")
                            param:          "MPC_XY_VEL_ALL"
                            min:            0.5
                            max:            20
                            step:           0.5
                        }
                    }
                }
            }

            Column {
                visible:                _mpc_z_vel_all

                QGCCheckBox {
                    id:                 zVelCheckbox
                    text:               qsTr("启用垂直速度滑块（如果启用，则会自动设置个体速度限制参数）")
                    checked:            _mpc_z_vel_all && _mpc_z_vel_all.value >= 0
                    onClicked: {
                        if (checked) {
                            _mpc_z_vel_all.value = Math.abs(_mpc_z_vel_all.value)
                        } else {
                            _mpc_z_vel_all.value = -Math.abs(_mpc_z_vel_all.value)
                        }
                    }
                }

                FactSliderPanel {
                    width:          availableWidth
                    enabled:        zVelCheckbox.checked

                    sliderModel: ListModel {
                        id:             zVelSlider

                        ListElement {
                            title:          qsTr("垂直速度（m/s）")
                            description:    qsTr("限制垂直速度（适用于所有模式）。")
                            param:          "MPC_Z_VEL_ALL"
                            min:            0.2
                            max:            8
                            step:           0.2
                        }
                    }
                }
            }

            FactSliderPanel {
                width:          availableWidth

                sliderModel: ListModel {
                    ListElement {
                        title:          qsTr("任务转弯半径")
                        description:    qsTr("增加此值会导致任务中的转弯更圆（角落切割）。使用最小化值以实现准确的角落跟踪。")
                        param:          "NAV_ACC_RAD"
                        min:            2
                        max:            16
                        step:           0.5
                    }
                }
            }

        } // Column
    } // Component - pageComponent
} // SetupPage
