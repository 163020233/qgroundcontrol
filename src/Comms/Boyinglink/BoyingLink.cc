#include "BoyingLink.h"
#include <QDebug>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
// QGC 自带 MAVLink 库
#include <mavlink.h>

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QJniObject>
#endif

// =========================================================
// BoyingWorker 实现
// =========================================================

void BoyingWorker::init()
{
    // 防止重复初始化
    if (_udpSocket != nullptr) {
        qDebug() << "BoyingWorker: Already initialized, skipping.";
        return;
    }

#ifdef Q_OS_ANDROID
    qDebug() << "BoyingWorker: Initializing UDP Mode...";

            // 1. JNI 初始化 (保持不变)
    _javaSdk = QJniObject("boying/sdk/BoyingSdk");
    if (!_javaSdk.isValid()) {
        qCritical() << "❌ Java class not found!";
        return;
    }
    _javaSdk.callMethod<jint>("InitSDKJava", "()I");
    _javaSdk.callMethod<jint>("StartSDKJava", "()I");

            // 2. 初始化 UDP 网络
    if (_initUdpSocket()) {
        qDebug() << "UDP Socket Bound Successfully!";
    } else {
        qCritical() << "❌ UDP Bind Failed!";
    }
#endif
}

bool BoyingWorker::_initUdpSocket()
{
    _udpSocket = new QUdpSocket(this);

            // 1. 设置发送目标 (系统服务在监听 14552)
    _targetIp = QHostAddress::Broadcast; // 多了个 l
    _targetPort = 14552;

            // 2. 绑定本地端口 (改为 14550，最有可能被转发服务认可的端口)
    quint16 localPort = 14550;

    qDebug() << "BoyingLink: Binding UDP to" << localPort << "Targeting:" << _targetPort;

            // 3. 尝试绑定
            // ShareAddress 和 ReuseAddressHint 很重要，防止端口占用冲突
    if (_udpSocket->bind(QHostAddress::Any, localPort, QAbstractSocket::ShareAddress | QAbstractSocket::ReuseAddressHint)) {

        connect(_udpSocket, &QUdpSocket::readyRead, this, &BoyingWorker::_onUdpReadyRead);

                // =========================================================
                // ★★★ 修正部分开始 ★★★
                // =========================================================

        // 1. 必须先创建定时器对象！(你漏了这句)
        _keepAliveTimer = new QTimer(this);

                // 2. 连接定时器信号
        connect(_keepAliveTimer, &QTimer::timeout, this, [=](){
            if (_udpSocket) {
                // --- 构造标准 MAVLink 心跳包 ---
                mavlink_message_t msg;
                uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

                        // ID=255(GCS), Type=GCS
                mavlink_msg_heartbeat_pack(255, 0, &msg,
                                           MAV_TYPE_GCS,
                                           MAV_AUTOPILOT_INVALID,
                                           MAV_MODE_MANUAL_ARMED,
                                           0, MAV_STATE_ACTIVE);

                uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
                QByteArray heartbeat((char*)buffer, len);

                        // --- 发送给 14552 ---
                        // qDebug() << "Sending Heartbeat..."; // 调试时可打开
                _udpSocket->writeDatagram(heartbeat, _targetIp, _targetPort);

                qint64 bytesSent = _udpSocket->writeDatagram(heartbeat, _targetIp, _targetPort);

                if (bytesSent == -1) {
                    qCritical() << "TX Fail:" << _udpSocket->errorString();
                } else {
                    // 每秒打印一次，确认心跳正在跳动
                    qDebug() << "TX Heartbeat ->" << _targetIp.toString() << ":" << _targetPort;
                }
            }
        });

                // 3. 必须启动定时器！(你也漏了这句)
        _keepAliveTimer->start(1000); // 1000毫秒 = 1秒发一次

        // =========================================================
        // ★★★ 修正部分结束 ★★★
        // =========================================================

        return true;
    }

    qCritical() << "UDP Error:" << _udpSocket->errorString();
    return false;
}
// ★★★ 接收逻辑：UDP -> SDK -> QGC ★★★
void BoyingWorker::_onUdpReadyRead()
{
#ifdef Q_OS_ANDROID
    while (_udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(int(_udpSocket->pendingDatagramSize()));

        QHostAddress sender;
        quint16 senderPort;

        // 读取 UDP 数据包
        _udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        // 如果需要过滤来源 IP，可以在这里加判断
        // if (sender != _targetIp) continue;

                // --- 下面的逻辑和串口版完全一样 ---
                // 1. 喂给 JNI
        QJniEnvironment env;
        jbyteArray jData = env->NewByteArray(datagram.size());
        env->SetByteArrayRegion(jData, 0, datagram.size(), reinterpret_cast<jbyte*>(datagram.data()));

        QJniObject jJsonArray = _javaSdk.callObjectMethod(
            "onReceive",
            "([BI)Lcom/alibaba/fastjson/JSONArray;",
            jData,
            (jint)datagram.size()
            );
        env->DeleteLocalRef(jData);

                // 2. 处理 JSON
        if (jJsonArray.isValid()) {
            QString jsonStr = jJsonArray.toString();
            if (!jsonStr.isEmpty()) {
                _processJsonData(jsonStr); // 这个函数和之前一样，不用改
            }
        }
    }
#endif
}

// 将 SDK 的 JSON 转成 MAVLink
void BoyingWorker::_processJsonData(const QString& jsonStr)
{
    // 这里你需要根据厂商具体的 JSON 格式来写
    // 举例：[{"byType":0, "custom_mode":2}, {"byType":9, "roll":...}]
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());

    if (doc.isArray()) {
        QJsonArray arr = doc.array();
        for (const auto& val : arr) {
            QJsonObject obj = val.toObject();
            int type = obj.value("byType").toInt();

            mavlink_message_t msg;
            uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
            bool send = false;

            // --- 映射逻辑 ---
            if (type == 0) { // 心跳
                int customMode = obj.value("custom_mode").toInt();
                // 查表转换...
                uint32_t px4Mode = 0;
                if(customMode == 2) px4Mode = 196608;
                // ...
                mavlink_msg_heartbeat_pack(1, 1, &msg, 2, 12, 1, px4Mode, 4);
                send = true;
            }
            else if (type == 9) { // 姿态
                // ...
                send = true;
            }

            if (send) {
                uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
                emit dataReceived(QByteArray((char*)buffer, len));
            }
        }
    }
}

// ★★★ 发送逻辑：QGC -> SDK -> 硬件 ★★★
void BoyingWorker::sendData(const QByteArray bytes)
{
#ifdef Q_OS_ANDROID
    if (!_udpSocket) return;

    mavlink_message_t msg;
    mavlink_status_t status;

    for (int i = 0; i < bytes.length(); i++) {
        if (mavlink_parse_char(MAVLINK_COMM_0, (uint8_t)bytes[i], &msg, &status)) {

            QString jsonCmd;

            // 1. MAVLink -> 厂商 JSON
            switch (msg.msgid) {
                case MAVLINK_MSG_ID_COMMAND_LONG: {
                    mavlink_command_long_t cmd;
                    mavlink_msg_command_long_decode(&msg, &cmd);

                    if (cmd.command == MAV_CMD_NAV_TAKEOFF) {
                        jsonCmd = "{\"byCommand\":\"TakeOff\", \"alt\":5.0}";
                    }
                    else if (cmd.command == MAV_CMD_COMPONENT_ARM_DISARM) {
                        jsonCmd = (cmd.param1 == 1) ? "{\"byCommand\":\"DisArm\"}" : "{\"byCommand\":\"Arm\"}";
                    }
                    break;
                }
            }

            if (!jsonCmd.isEmpty()) {
                // 调用 JNI 编码
                QJniObject jStr = QJniObject::fromString(jsonCmd);
                QJniObject jBytesObj = _javaSdk.callObjectMethod(
                    "GetByteByJsonJava",
                    "(Ljava/lang/String;)[B",
                    jStr.object<jstring>()
                    );

                if (jBytesObj.isValid()) {
                    jbyteArray jBytes = jBytesObj.object<jbyteArray>();
                    QJniEnvironment env;
                    jsize len = env->GetArrayLength(jBytes);
                    QByteArray finalBytes;
                    finalBytes.resize(len);
                    env->GetByteArrayRegion(jBytes, 0, len, reinterpret_cast<jbyte*>(finalBytes.data()));

                    // ★★★ 核心区别：写入 UDP 而不是串口 ★★★
                    _udpSocket->writeDatagram(finalBytes, _targetIp, _targetPort);
                }
            }
#endif
        }
    }
}

void BoyingWorker::cleanup()
{
    if (_udpSocket) {
        _udpSocket->close();
        delete _udpSocket;
        _udpSocket = nullptr;
    }
#ifdef Q_OS_ANDROID
    if (_javaSdk.isValid()) {
        _javaSdk.callMethod<jint>("StopSDKJava", "()I");
    }
#endif
}

// =========================================================
// BoyingLink (主线程) - 这部分基本不用动
// =========================================================

BoyingLink::BoyingLink(SharedLinkConfigurationPtr& config)
    : LinkInterface(config)
    , _is_connected(false)
    , _thread(nullptr)
    , _worker(nullptr)
{
}

BoyingLink::~BoyingLink()
{
    disconnect();
}

bool BoyingLink::isConnected(void) const
{
    return _is_connected;
}

bool BoyingLink::_connect(void)
{
    if (_is_connected) return true;

    _thread = new QThread(this);
    _worker = new BoyingWorker();
    _worker->moveToThread(_thread);

    connect(this, &BoyingLink::_workerInit, _worker, &BoyingWorker::init);
    connect(this, &BoyingLink::_workerSend, _worker, &BoyingWorker::sendData);
    connect(this, &BoyingLink::_workerCleanup, _worker, &BoyingWorker::cleanup);
    connect(_worker, &BoyingWorker::dataReceived, this, &BoyingLink::_onWorkerData);

    // 线程清理
    connect(_thread, &QThread::finished, _worker, &QObject::deleteLater);
    connect(_thread, &QThread::finished, _thread, &QObject::deleteLater);

    _thread->start();
    emit _workerInit();

    _is_connected = true;
    emit connected();

    return true;
}

void BoyingLink::disconnect(void)
{
    if (_worker) emit _workerCleanup();
    if (_thread) {
        _thread->quit();
        _thread->wait();
        _thread = nullptr;
        _worker = nullptr;
    }
    if (_is_connected) {
        _is_connected = false;
        emit disconnected();
    }
}

void BoyingLink::_writeBytes(const QByteArray& bytes)
{
    if (_is_connected) emit _workerSend(bytes);
}

void BoyingLink::_onWorkerData(QByteArray data)
{
    emit bytesReceived(this, data);
}
