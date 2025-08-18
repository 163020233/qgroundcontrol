import QtQuick
import QtQuick.Controls

import QGroundControl.FactSystem
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.Controllers

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    ESP8266ComponentController {
        id:         esp8266
    }

    property Fact debugEnabled:     controller.getParameterFact(esp8266.componentID, "DEBUG_ENABLED")
    property Fact wifiChannel:      controller.getParameterFact(esp8266.componentID, "WIFI_CHANNEL")
    property Fact wifiHostPort:     controller.getParameterFact(esp8266.componentID, "WIFI_UDP_HPORT")
    property Fact wifiClientPort:   controller.getParameterFact(esp8266.componentID, "WIFI_UDP_CPORT")
    property Fact uartBaud:         controller.getParameterFact(esp8266.componentID, "UART_BAUDRATE")
    property Fact wifiMode:         controller.getParameterFact(esp8266.componentID, "WIFI_MODE", false) //-- Don't bitch if missing

    Column {
        anchors.fill:       parent
        VehicleSummaryRow {
            labelText: qsTr("固件版本")
            valueText: esp8266.version
        }
        VehicleSummaryRow {
            labelText: qsTr("WiFi模式")
            valueText: wifiMode ? (wifiMode.value === 0 ? qsTr("AP模式") : qsTr("站模式")) : qsTr("AP模式")
        }
        VehicleSummaryRow {
            labelText:  qsTr("WiFi通道")
            valueText:  wifiChannel ? wifiChannel.valueString : ""
            visible:    wifiMode ? wifiMode.value === 0 : true
        }
        VehicleSummaryRow {
            labelText: qsTr("WiFi AP SSID")
            valueText: esp8266.wifiSSID
        }
        VehicleSummaryRow {
            labelText: qsTr("WiFi AP 密码")
            valueText: esp8266.wifiPassword
        }
        /* Too much info makes it all crammed
        VehicleSummaryRow {
            labelText: qsTr("WiFi STA SSID")
            valueText: esp8266.wifiSSIDSta
        }
        VehicleSummaryRow {
            labelText: qsTr("WiFi STA Password")
            valueText: esp8266.wifiPasswordSta
        }
        */
        VehicleSummaryRow {
            labelText: qsTr("UART 波特率")
            valueText: uartBaud ? uartBaud.valueString : ""
        }
    }
}
