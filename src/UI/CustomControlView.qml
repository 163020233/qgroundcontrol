// CustomControlView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtLocation 5.15
import QtPositioning 5.15
import QGroundControl

Item {
    anchors.fill: parent
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    Column {
        anchors.centerIn: parent
        spacing: 20

        Button {
            text: "起飞"
            enabled: vehicle && vehicle.armed && vehicle.guidedMode
            onClicked: {
                vehicle.guidedTakeoff(10)
            }
        }

        Button {
            text: "降落"
            enabled: vehicle
            onClicked: {
                vehicle.sendMavCommand(
                    0, 0,
                    MAV_CMD_NAV_LAND,
                    false, 0, 0, 0, 0, 0, 0, 0
                )
            }
        }

        Text {
            text: vehicle ? ("电压: " + vehicle.battery.voltage.valueString + " V") : "未连接"
            font.pixelSize: 18
        }
    }

    // // 地图（可选）
    // Map {
    //     id: simpleMap
    //     anchors.left: parent.left
    //     anchors.right: parent.right
    //     anchors.bottom: parent.bottom
    //     height: parent.height / 2
    //
    //     plugin: Plugin { name: "osm" }
    //     center: QtPositioning.coordinate(39.9, 116.4)
    //     zoomLevel: 15
    //
    //     MapQuickItem {
    //         coordinate: vehicle ? vehicle.coordinate : QtPositioning.coordinate(0, 0)
    //         anchorPoint.x: 16
    //         anchorPoint.y: 16
    //         sourceItem: Rectangle {
    //             width: 16; height: 16
    //             color: "red"; radius: 8
    //         }
    //     }
    // }
}