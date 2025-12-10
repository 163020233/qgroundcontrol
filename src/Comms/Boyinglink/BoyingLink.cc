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
#include <QtMath> // 用于 qDegreesToRadians

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
// 虚拟参数表 (用于欺骗 QGC 完成初始化)
// =========================================================
struct MockParam {
    const char* id;
    float value;
    uint8_t type; // 6=INT32, 9=REAL32
};

// 虚拟参数定义
static const MockParam s_mockParams[] = {
    // 基础身份
    {"SYS_AUTOSTART",   4001.0f, 6},
    {"MAV_TYPE",        2.0f,    6},
    {"MAV_PROTO_VER",   200.0f,  6}, // 协议版本 2.0

    // ★★★ 核心作弊码：禁用所有报错检查 ★★★
    {"COM_RC_IN_MODE",  1.0f,    6}, // 1 = 虚拟摇杆模式 (不检查遥控器)
    {"NAV_RCL_ACT",     0.0f,    6}, // 0 = 禁用失控返航检查

    // 假装传感器已校准 (给个非0的ID即可)
    {"CAL_ACC0_ID",     1234.0f, 6},
    {"CAL_GYRO0_ID",    1234.0f, 6},
    {"CAL_MAG0_ID",     1234.0f, 6},

    // 禁用电源和USB检查 (Key: 894281 是 PX4 的魔术数字)
    {"CBRK_SUPPLY_CHK", 894281.0f, 6},
    {"CBRK_USB_CHK",    197848.0f, 6},

    // 允许无 GPS 解锁 (以防万一)
    {"COM_ARM_WO_GPS",  1.0f,    6},

    // 飞行参数
    {"BAT_N_CELLS",     4.0f,    6},
    {"MIS_TAKEOFF_ALT", 10.0f,   9},
    {"RTL_RETURN_ALT",  30.0f,   9}
};
static const int s_paramCount = sizeof(s_mockParams)/sizeof(MockParam);
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
    QJsonArray msgArray;
    if (root.contains("msg")) {
        msgArray = root.value("msg").toArray();
    } else {
        msgArray.append(root);
    }

    for (const auto& val : msgArray) {
        QJsonObject obj = val.toObject();
        int type = obj.value("byType").toInt();

        mavlink_message_t msg;
        uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

        // =========================================================
        // 1. 心跳包 (Type 0) + 强制捆绑发送 GPS
        // =========================================================
        if (type == 0) {
            // --- A. 处理心跳 ---
            int customMode = obj.value("custom_mode").toInt();
            uint32_t px4Mode = 65536; // Manual

            // 简单映射
            if (customMode == 2) px4Mode = 196608; // Altitude
            else if (customMode == 3) px4Mode = 262144; // Position
            else if (customMode == 4) px4Mode = 67108864; // Mission

            mavlink_msg_heartbeat_pack(1, 1, &msg,
                MAV_TYPE_QUADROTOR, MAV_AUTOPILOT_PX4,
                MAV_MODE_FLAG_CUSTOM_MODE_ENABLED, px4Mode, MAV_STATE_ACTIVE);

            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));

            // --- B. ★★★ 强制捆绑发送伪造 GPS (解决室内无数据问题) ★★★ ---
            // 只要心跳在跳，GPS 就满格！
            {
                mavlink_gps_raw_int_t gps;
                memset(&gps, 0, sizeof(gps));

                gps.time_usec = 0;
                gps.fix_type = 3;       // ★ 3D Fix (关键)
                gps.lat = 399087220;    // ★ 北京天安门 (非0值)
                gps.lon = 1163974960;
                gps.alt = 50000;        // 50m
                gps.eph = 50;           // ★ 精度极高 (0.5m)
                gps.epv = 50;
                gps.vel = 0;
                gps.satellites_visible = 15; // ★ 15颗星

                mavlink_message_t gpsMsg;
                mavlink_msg_gps_raw_int_encode(1, 1, &gpsMsg, &gps);
                uint16_t gpsLen = mavlink_msg_to_send_buffer(buffer, &gpsMsg);
                emit dataReceived(QByteArray((char*)buffer, gpsLen));
            }

            // --- C. ★★★ 顺便发一个 SYS_STATUS (解决 Not Ready) ★★★ ---
            {
                mavlink_sys_status_t sys;
                memset(&sys, 0, sizeof(sys));
                uint32_t sensors = MAV_SYS_STATUS_SENSOR_3D_GYRO | MAV_SYS_STATUS_SENSOR_3D_ACCEL |
                                   MAV_SYS_STATUS_SENSOR_3D_MAG | MAV_SYS_STATUS_SENSOR_ABSOLUTE_PRESSURE |
                                   MAV_SYS_STATUS_SENSOR_GPS;
                sys.onboard_control_sensors_present = sensors;
                sys.onboard_control_sensors_enabled = sensors;
                sys.onboard_control_sensors_health  = sensors;
                sys.voltage_battery = 24000; // 24V
                sys.battery_remaining = 80;

                mavlink_message_t sysMsg;
                mavlink_msg_sys_status_encode(1, 1, &sysMsg, &sys);
                uint16_t sysLen = mavlink_msg_to_send_buffer(buffer, &sysMsg);
                emit dataReceived(QByteArray((char*)buffer, sysLen));
            }
        }

        // =========================================================
        // 2. 姿态 (Type 9)
        // =========================================================
        else if (type == 9) {
            float roll = obj.value("roll").toDouble() * 3.1415926 / 180.0;
            float pitch = obj.value("pitch").toDouble() * 3.1415926 / 180.0;
            float yaw = obj.value("yaw").toDouble() * 3.1415926 / 180.0;

            mavlink_msg_attitude_pack(1, 1, &msg, 0, roll, pitch, yaw, 0, 0, 0);

            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));
        }

        // =========================================================
        // 3. 真实的 GPS (Type 3) - 如果有，覆盖上面的假数据
        // =========================================================
        else if (type == 3) {
            int fix = obj.value("fixType").toInt();
            // 只有当真实 GPS 锁定 (>=2) 时，才转发真实数据
            // 否则就让上面的假数据撑场面
            if (fix >= 2) {
                int lat = obj.value("lat").toInt();
                int lon = obj.value("lon").toInt();
                int alt = obj.value("alt").toInt();
                int sat = obj.value("count").toInt();

                mavlink_gps_raw_int_t gps;
                memset(&gps, 0, sizeof(gps));
                gps.fix_type = (uint8_t)fix;
                gps.lat = lat;
                gps.lon = lon;
                gps.alt = alt;
                gps.satellites_visible = (uint8_t)sat;
                gps.eph = 100;
                gps.epv = 100;

                mavlink_msg_gps_raw_int_encode(1, 1, &msg, &gps);
                uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
                emit dataReceived(QByteArray((char*)buffer, len));
            }
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

            // =========================================================
            // ★★★ 核心修改：拦截参数请求，使用【异步】发送 ★★★
            // =========================================================
            if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_LIST) {
                qDebug() << "QGC asking for params. Starting ASYNC send...";

                // 使用 lambda + invokeMethod 将发送逻辑推迟执行，避免阻塞当前流程
                QMetaObject::invokeMethod(this, [=](){
                    for (int j = 0; j < s_paramCount; j++) {
                        mavlink_message_t txMsg;
                        uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

                        mavlink_param_value_t p;
                        strncpy(p.param_id, s_mockParams[j].id, 16);
                        p.param_value = s_mockParams[j].value;
                        p.param_type = s_mockParams[j].type;
                        p.param_count = s_paramCount;
                        p.param_index = j;

                        // ★★★ 重点：Component ID 必须是 1 ★★★
                        mavlink_msg_param_value_encode(1, 1, &txMsg, &p);
                        uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);

                        emit dataReceived(QByteArray((char*)buffer, len));

                        // ★★★ 重点：加大延时到 50ms ★★★
                        // 给 QGC 一点喘息时间来处理上一个包
                        QThread::msleep(50);
                    }
                    qDebug() << " All mock params sent successfully.";
                }, Qt::QueuedConnection);

                continue; // 拦截成功，跳过后续逻辑
            }
            // 2. ★★★ 新增：处理【请求单个参数/补发】 ★★★
            else if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_READ) {
                mavlink_param_request_read_t req;
                mavlink_msg_param_request_read_decode(&msg, &req);

                // QGC 可能会按索引请求 (param_index != -1)
                if (req.param_index != -1 && req.param_index < s_paramCount) {
                    int idx = req.param_index;
                    qDebug() << "QGC missed param" << idx << ", resending...";

                    mavlink_message_t txMsg;
                    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

                    mavlink_param_value_t p;
                    strncpy(p.param_id, s_mockParams[idx].id, 16);
                    p.param_value = s_mockParams[idx].value;
                    p.param_type = s_mockParams[idx].type;
                    p.param_count = s_paramCount;
                    p.param_index = idx; // 告诉 QGC 这是第几个

                    // Component ID 必须是 1
                    mavlink_msg_param_value_encode(1, 1, &txMsg, &p);
                    uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);

                    emit dataReceived(QByteArray((char*)buffer, len));
                }
                continue; // 拦截成功，跳过后续逻辑
            }
            // =========================================================
            // 2. ★★★ 新增：航点协议 (Mission Protocol) ★★★
            // 解决 "Mission request list failed" 报错
            // =========================================================
            else if (msg.msgid == MAVLINK_MSG_ID_MISSION_REQUEST_LIST) {
                qDebug() << "QGC asking for Mission List. Sending Count = 0...";

                mavlink_message_t txMsg;
                uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

                // 回复 MISSION_COUNT = 0 (告诉 QGC 我没有航点)
                // 参数：SystemID, CompID, TargetSys, TargetComp, Count, MissionType
                mavlink_msg_mission_count_pack(
                    1, 1,    // 我的 ID (必须是 1, 1)
                    &txMsg,
                    msg.sysid,
                    msg.compid, // 发给 QGC (原路返回)
                    0,       // ★★★ 关键：数量 = 0 ★★★
                    MAV_MISSION_TYPE_MISSION, // 任务类型
                    0
                );

                uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                emit dataReceived(QByteArray((char*)buffer, len));

                continue; // 拦截成功，不发给飞控
            }
            // =========================================================
            // 下面是正常的控制指令转发 (保持不变)
            // =========================================================
            QString jsonCmd;
            switch (msg.msgid) {
                case MAVLINK_MSG_ID_COMMAND_LONG: {
                    mavlink_command_long_t cmd;
                    mavlink_msg_command_long_decode(&msg, &cmd);
                    // 起飞
                    if (cmd.command == MAV_CMD_NAV_TAKEOFF) {
                        jsonCmd = QString("{\"byCommand\":\"TakeOff\", \"alt\":%1}").arg(cmd.param7 > 0 ? cmd.param7 : 5.0);
                    }
                    // 解锁/上锁
                    else if (cmd.command == MAV_CMD_COMPONENT_ARM_DISARM) {
                        jsonCmd = QString("{\"byCommand\":\"%1\"}").arg(cmd.param1 == 1 ? "DisArm" : "Arm");
                    }
                    break;
                }
            }

            if (!jsonCmd.isEmpty()) {
                // JNI 发送逻辑 (保持你之前的代码)
                QJniObject jStr = QJniObject::fromString(jsonCmd);
                QJniObject jBytesObj = _javaSdk.callObjectMethod(
                    "GetByteByJsonJava", "(Ljava/lang/String;)[B", jStr.object<jstring>()
                );
                if (jBytesObj.isValid()) {
                    jbyteArray jBytes = jBytesObj.object<jbyteArray>();
                    QJniObject::callStaticMethod<void>(
                        "org/qjkj/gcs/QGCConnectionManager",
                        "sendData", "([B)V", jBytes
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
