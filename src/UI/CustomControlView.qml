import QtQuick 2.15
import QtQuick.Controls 2.15
import QGroundControl 1.0

Item {
    width: 300
    height: 200

    property string selectedPort: ""

    Column {
        spacing: 16
        anchors.centerIn: parent

        Text {
            text: "串口选择"
            font.bold: true
            font.pointSize: 14
        }

        ComboBox {
            id: portSelector
            width: parent.width
            model: QGroundControl.linkManager.serialPorts
            textRole: "portName"
            onCurrentIndexChanged: {
                if (model.length > 0) {
                    selectedPort = model[currentIndex].portName
                }
            }
        }

        Button {
            text: "连接串口"
            width: parent.width
            onClicked: {
                if (!selectedPort || selectedPort === "") {
                    console.warn("未选择串口")
                    return
                }

                let config = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeSerial, "MySerialLink")
                config.portName = selectedPort
                config.baud = 57600

                let link = QGroundControl.linkManager.addLink(config)
                if (link) {
                    QGroundControl.linkManager.connectLink(link)
                    console.log("已尝试连接到串口: " + selectedPort)
                } else {
                    console.warn("创建链接失败")
                }
            }
        }

        Text {
            text: "当前选中: " + selectedPort
            font.pointSize: 12
        }
    }
}


