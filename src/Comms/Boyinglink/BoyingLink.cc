/****************************************************************************
 *   BoyingLink.cc
 *   Implementation of Boying SDK Link for QGroundControl (Hybrid Java Architecture)
 ****************************************************************************/

#include "BoyingLink.h"
#include <QDebug>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

// MAVLink 解析库
#include <mavlink.h>

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QJniObject>
#include <jni.h>
#endif

// =========================================================
// JNI 全局变量与回调实现
// =========================================================

#ifdef Q_OS_ANDROID
// 全局 Worker 指针，用于 JNI 回调
static BoyingWorker* s_worker = nullptr;
static QMutex s_sdkMutex;
static bool s_isSdkInitialized = false;

extern "C" {
    // 对应 Java 类: org.qjkj.gcs.QGCConnectionManager
    // 方法: nativeOnDataReceived(byte[] data, int length)
    JNIEXPORT void JNICALL
    Java_org_qjkj_gcs_QGCConnectionManager_nativeOnDataReceived(JNIEnv *env, jclass, jbyteArray data, jint len) {
        if (!s_worker) return;

        // 1. 将 Java byte[] 拷贝到 C++ QByteArray
        jbyte* buf = env->GetByteArrayElements(data, NULL);
        QByteArray rawData((char*)buf, len);
        env->ReleaseByteArrayElements(data, buf, JNI_ABORT);

        // 2. 线程安全地交给 Worker 处理
        // 使用 invokeMethod 将执行权切回 Worker 线程
        QMetaObject::invokeMethod(s_worker, "onJavaDataReceived", Qt::QueuedConnection, Q_ARG(QByteArray, rawData));
    }
}
#endif

// =========================================================
// BoyingWorker 实现 (跑在子线程)
// =========================================================

void BoyingWorker::init()
{
#ifdef Q_OS_ANDROID
    QMutexLocker locker(&s_sdkMutex);

    // 防止重复初始化
    if (s_isSdkInitialized) {
        qDebug() << "Second instance detected! Aborting.";
        return;
    }

    qDebug() << "BoyingWorker: Initializing Hybrid Link...";
    s_worker = this; // 注册单例

    // 1. 初始化 Boying SDK (翻译官)
    _javaSdk = QJniObject("boying/sdk/BoyingSdk");
    if (!_javaSdk.isValid()) {
        qCritical() << "BoyingSdk class not found!";
        return;
    }

    jint retInit = _javaSdk.callMethod<jint>("InitSDKJava", "()I");
    if (retInit != 0) {
        qCritical() << "SDK Init failed:" << retInit;
        return;
    }
    _javaSdk.callMethod<jint>("StartSDKJava", "()I");

    // 2. 初始化 硬件连接 (通过 QGCConnectionManager)
    qDebug() << " Attempting to call QGCConnectionManager.initConnection()...";

    QJniObject::callStaticMethod<void>(
        "org/qjkj/gcs/QGCConnectionManager", // 类名
        "initConnection",                    // 方法名
        "()V"                                // 签名
    );

    // ★★★ 新增：JNI 异常检查 (照妖镜) ★★★
    QJniEnvironment env;
    if (env.checkAndClearExceptions()) {
        qCritical() << "JNI CALL FAILED! ";
        qCritical() << "Possible reasons:";
        qCritical() << "1. Java file path is wrong (must match package structure)";
        qCritical() << "2. Class name or Method name typo";
        return; // 不要设置 s_isSdkInitialized = true
    }

    s_isSdkInitialized = true;
    qDebug() << "✅ Hybrid Link Initialized!";
#endif
}

// ★★★ 接收逻辑：Java硬件层 -> JNI -> 这里 -> SDK解析 -> MAVLink ★★★
void BoyingWorker::onJavaDataReceived(const QByteArray& rawData)
{
#ifdef Q_OS_ANDROID
    if (rawData.isEmpty()) return;

    // 1. 喂给 Boying SDK 进行解析 (GetJsonByByteJava)
    QJniEnvironment env;
    jbyteArray jData = env->NewByteArray(rawData.size());
    env->SetByteArrayRegion(jData, 0, rawData.size(), reinterpret_cast<const  jbyte*>(rawData.data()));

    // 调用 JNI
    QJniObject jJsonStr = _javaSdk.callObjectMethod(
        "GetJsonByByteJava",
        "([BI)Ljava/lang/String;",
        jData,
        (jint)rawData.size()
    );
    env->DeleteLocalRef(jData);

    // 2. 处理解析结果
    if (jJsonStr.isValid()) {
        QString jsonString = jJsonStr.toString();
        if (!jsonString.isEmpty()) {
            // qDebug() << "RX JSON:" << jsonString; // 调试可开
            _processJsonData(jsonString);
        }
    }
#endif
}

// ★★★ 协议翻译核心: JSON -> MAVLink ★★★
void BoyingWorker::_processJsonData(const QString& jsonStr)
{
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (!doc.isObject()) return;

    QJsonObject root = doc.object();
    if (!root.contains("msg")) return;

    QJsonArray msgArray = root.value("msg").toArray();

    for (const auto& val : msgArray) {
        QJsonObject obj = val.toObject();
        int type = obj.value("byType").toInt();

        mavlink_message_t msg;
        uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
        bool send = false;

        // --- 1. 心跳包 (Type 0) ---
        if (type == 0) {
            int customMode = obj.value("custom_mode").toInt();
            uint32_t px4Mode = 0; // Manual
            if (customMode == 2) px4Mode = 196608; // AltCtl
            if (customMode == 3) px4Mode = 262144; // PosCtl
            if (customMode == 4) px4Mode = 67108864; // Auto

            mavlink_msg_heartbeat_pack(1, 1, &msg,
                MAV_TYPE_QUADROTOR, MAV_AUTOPILOT_PX4,
                MAV_MODE_FLAG_CUSTOM_MODE_ENABLED, px4Mode, MAV_STATE_ACTIVE);
            send = true;
        }

        // --- 2. 姿态 (Type 9) ---
        else if (type == 9) {
            float roll = obj.value("roll").toDouble();
            float pitch = obj.value("pitch").toDouble();
            float yaw = obj.value("yaw").toDouble();
            mavlink_msg_attitude_pack(1, 1, &msg, 0, roll, pitch, yaw, 0, 0, 0);
            send = true;
        }

        // --- 3. GPS (Type 3) ---
        else if (type == 3) {
            int lat = obj.value("lat").toInt();
            int lon = obj.value("lon").toInt();
            int alt = obj.value("alt").toInt();
            int fix = obj.value("fixType").toInt();
            int sat = obj.value("count").toInt();

            // 使用强制类型转换适配 v2.0
            mavlink_msg_gps_raw_int_pack(
                1, 1, &msg, 0, (uint8_t)fix, (int32_t)lat, (int32_t)lon, (int32_t)alt,
                0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, (uint8_t)sat,
                0,0,0,0,0,0 // v2.0 新增字段置0
            );
            send = true;
        }

        if (send) {
            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));
        }
    }
}

// ★★★ 发送逻辑: QGC -> JSON -> SDK -> Java硬件层 ★★★
void BoyingWorker::sendData(const QByteArray bytes)
{
#ifdef Q_OS_ANDROID
    if (!_javaSdk.isValid()) return;

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
                        jsonCmd = QString("{\"byCommand\":\"TakeOff\", \"alt\":%1}").arg(cmd.param7 > 0 ? cmd.param7 : 5.0);
                    }
                    else if (cmd.command == MAV_CMD_COMPONENT_ARM_DISARM) {
                        jsonCmd = QString("{\"byCommand\":\"%1\"}").arg(cmd.param1 == 1 ? "DisArm" : "Arm"); // 注意厂商可能反逻辑
                    }
                    break;
                }
            }

            // 2. JSON -> SDK编码 -> Java发送
            if (!jsonCmd.isEmpty()) {
                QJniObject jStr = QJniObject::fromString(jsonCmd);

                // 编码
                QJniObject jBytesObj = _javaSdk.callObjectMethod(
                    "GetByteByJsonJava",
                    "(Ljava/lang/String;)[B",
                    jStr.object<jstring>()
                );

                if (jBytesObj.isValid()) {
                    jbyteArray jBytes = jBytesObj.object<jbyteArray>();
                    QJniEnvironment env;
                    jsize len = env->GetArrayLength(jBytes);

                    // 这里的技巧：不需要转回 C++ QByteArray 再转回 Java
                    // 直接把 jByteArray 传给 QGCConnectionManager

                    QJniObject::callStaticMethod<void>(
                        "org/qjkj/gcs/QGCConnectionManager",
                        "sendData",
                        "([B)V",
                        jBytes // 直接传
                    );
                }
            }
        }
    }
#endif
}

void BoyingWorker::cleanup()
{
#ifdef Q_OS_ANDROID
    QMutexLocker locker(&s_sdkMutex);
    if (s_isSdkInitialized) {
        if (_javaSdk.isValid()) {
            _javaSdk.callMethod<jint>("StopSDKJava", "()I");
        }
        s_isSdkInitialized = false;
        s_worker = nullptr; // 清空指针
    }
#endif
}

// =========================================================
// BoyingLink (主线程部分，保持不变)
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
