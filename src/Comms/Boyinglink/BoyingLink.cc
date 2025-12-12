/****************************************************************************
 *   BoyingLink.cc
 *   Implementation of Boying SDK Link for QGroundControl (Hybrid Java Architecture)
 ****************************************************************************/

#include "BoyingLink.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QtMath> // qDegreesToRadians

// MAVLink 解析库
#include <mavlink.h>
#include <QPointer> // ★★★ 必须加 ★★★
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
// static BoyingWorker* s_worker = nullptr;
static bool s_isSdkInitialized = false;
static QMutex s_workerMutex; // ★ 新增互斥锁
static QPointer<BoyingWorker> s_worker; // ★★★ 使用 QPointer ★★★

extern "C" {
    JNIEXPORT void JNICALL
    Java_org_qjkj_gcs_QGCConnectionManager_nativeOnDataReceived(JNIEnv *env, jclass, jbyteArray data, jint len) {

        QMutexLocker locker(&s_workerMutex);

        // ★★★ QPointer 检查：如果对象已销毁，s_worker 会自动变为 null，绝对安全 ★★★
        if (s_worker.isNull()) {
            // qDebug() << "JNI: Worker is dead, ignoring data.";
            return;
        }

        jbyte* buf = env->GetByteArrayElements(data, NULL);
        if (!buf) return;

        QByteArray rawData((char*)buf, len);
        env->ReleaseByteArrayElements(data, buf, JNI_ABORT);

        // 使用 s_worker.data() 获取原始指针
        QMetaObject::invokeMethod(s_worker.data(), "onJavaDataReceived", Qt::QueuedConnection, Q_ARG(QByteArray, rawData));
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

static const MockParam s_mockParams[] = {
    {"SYS_AUTOSTART",   4001.0f, 6},
    {"MAV_TYPE",        2.0f,    6},
    {"MAV_PROTO_VER",   200.0f,  6},
    {"COM_RC_IN_MODE",  1.0f,    6},
    {"NAV_RCL_ACT",     0.0f,    6},
    {"COM_ARM_CHK_ES",  0.0f,    6},
    {"CBRK_SUPPLY_CHK", 894281.0f, 6},
    {"CBRK_USB_CHK",    197848.0f, 6},
    {"COM_ARM_WO_GPS",  1.0f,    6},
    {"CAL_ACC0_ID",     1234.0f, 6},
    {"CAL_GYRO0_ID",    1234.0f, 6},
    {"CAL_MAG0_ID",     1234.0f, 6},
    {"BAT_N_CELLS",     4.0f,    6},
    {"MIS_TAKEOFF_ALT", 10.0f,   9},
    {"RTL_RETURN_ALT",  30.0f,   9}
};
static const int s_paramCount = sizeof(s_mockParams)/sizeof(MockParam);

// 辅助函数：解码 Unicode
QString unescapeUnicode(const QString& str) {
    QString result = "";
    int i = 0;
    while (i < str.length()) {
        if (str.mid(i, 2) == "\\u") {
            QString code = str.mid(i + 2, 4);
            bool ok;
            int hex = code.toInt(&ok, 16);
            if (ok) {
                result.append(QChar(hex));
                i += 6;
                continue;
            }
        }
        result.append(str.at(i));
        i++;
    }
    return result;
}

// =========================================================
// BoyingWorker 实现
// =========================================================

void BoyingWorker::init()
{
#ifdef Q_OS_ANDROID
    // 1. 【第一阶段加锁】：检查状态 & 注册指针
    {
        QMutexLocker locker(&s_workerMutex);

        if (s_isSdkInitialized) {
            qDebug() << "Second instance detected! Aborting.";
            return;
        }

        // QPointer 可以直接赋值原生指针
        s_worker = this;
    } // <--- 出了大括号，锁自动释放！防止死锁！

    qDebug() << "BoyingWorker: Initializing Hybrid Link...";

    // 2. 【无锁阶段】：执行耗时的 JNI 操作
    // 此时如果有数据回调进来，nativeOnDataReceived 可以获取到锁，也能用到 s_worker

    _javaSdk = QJniObject("boying/sdk/BoyingSdk");
    if (!_javaSdk.isValid()) {
        qCritical() << "BoyingSdk class not found!";
        return;
    }

    jint retInit = _javaSdk.callMethod<jint>("InitSDKJava", "()I");
    _javaSdk.callMethod<jint>("StartSDKJava", "()I");

    QJniObject::callStaticMethod<void>(
        "org/qjkj/gcs/QGCConnectionManager",
        "initConnection",
        "()V"
    );

    // 3. 【第二阶段加锁】：更新初始化标记
    {
        QMutexLocker locker(&s_workerMutex);
        s_isSdkInitialized = true;
    }

    qDebug() << "✅ Hybrid Link Initialized!";
#endif
}

void BoyingWorker::onJavaDataReceived(const QByteArray& rawData)
{
#ifdef Q_OS_ANDROID
    if (rawData.isEmpty()) return;
    // 打印长度，如果是少量数据可以打印 toHex()
    qDebug() << "🔵 [RX RAW] Len:" << rawData.size() << "Bytes:" << rawData.toHex();

    QJniEnvironment env;
    jbyteArray jData = env->NewByteArray(rawData.size());
    env->SetByteArrayRegion(jData, 0, rawData.size(), reinterpret_cast<const  jbyte*>(rawData.data()));

    QJniObject jJsonStr = _javaSdk.callObjectMethod(
        "GetJsonByByteJava",
        "([BI)Ljava/lang/String;",
        jData,
        (jint)rawData.size()
    );
    env->DeleteLocalRef(jData);

    if (jJsonStr.isValid()) {
        QString jsonString = jJsonStr.toString();

        if (!jsonString.isEmpty()) {
            // =========================================================
            // ★★★ 打印点 2: 确认 SDK 解析成功 (业务数据检查) ★★★
            // =========================================================
            qDebug() << "[RX JSON]" << jsonString;

            _processJsonData(jsonString);
        } else {
            qWarning() << "[RX Error] SDK returned Empty String (Parse Failed?)";
        }
    } else {
        qCritical() << "RX Error] JNI Call GetJsonByByteJava returned NULL";
    }
#endif
}

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
        bool send = false;

        // 1. 心跳包 (Type 0)
        if (type == 0) {
            int customMode = obj.value("custom_mode").toInt();
            int baseMode = obj.value("base_mode").toInt();
            int sysStatus = obj.value("system_status").toInt();

            uint32_t px4Mode = 65536; // Manual
            switch (customMode) {
                case 0:  px4Mode = 65536;    break;
                case 2:  px4Mode = 196608;   break;
                case 3:  px4Mode = 262144;   break;
                case 5:  px4Mode = 84148224; break;
                case 6:  px4Mode = 84148224; break;
                case 9:  px4Mode = 50593792; break;
                case 17: px4Mode = 83886080; break;
                default: px4Mode = 65536;    break;
            }

            bool isArmed = (baseMode & 128) == 128;
            uint8_t mavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
            if (isArmed) mavBaseMode |= MAV_MODE_FLAG_SAFETY_ARMED;

            uint8_t mavState = (sysStatus == 5) ? MAV_STATE_CRITICAL : MAV_STATE_ACTIVE;

            mavlink_msg_heartbeat_pack(1, 1, &msg,
                MAV_TYPE_QUADROTOR, MAV_AUTOPILOT_PX4,
                mavBaseMode, px4Mode, mavState);

            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));

            // 发送 SYS_STATUS
            {
                mavlink_sys_status_t sys;
                memset(&sys, 0, sizeof(sys));
                uint32_t sensors = 0xFC00FFFF; // 全健康掩码
                sys.onboard_control_sensors_present = sensors;
                sys.onboard_control_sensors_enabled = sensors;
                sys.onboard_control_sensors_health  = sensors;
                sys.voltage_battery = 16000;
                sys.battery_remaining = 80;
                mavlink_message_t sysMsg;
                mavlink_msg_sys_status_encode(1, 1, &sysMsg, &sys);
                len = mavlink_msg_to_send_buffer(buffer, &sysMsg);
                emit dataReceived(QByteArray((char*)buffer, len));
            }

            // 发送 ESTIMATOR_STATUS
            {
                mavlink_estimator_status_t est;
                memset(&est, 0, sizeof(est));
                est.flags = 0xFFFF; // 全好
                est.vel_ratio = 1.0f;
                est.pos_horiz_ratio = 1.0f;
                mavlink_message_t estMsg;
                mavlink_msg_estimator_status_encode(1, 1, &estMsg, &est);
                len = mavlink_msg_to_send_buffer(buffer, &estMsg);
                emit dataReceived(QByteArray((char*)buffer, len));
            }


            // --- A. 强制伪造 GPS_RAW_INT ---
            {
                mavlink_gps_raw_int_t gps;
                memset(&gps, 0, sizeof(gps));
                gps.fix_type = 3;       // 3D Fix
                gps.lat = 399087220;    // 纬度 (北京)
                gps.lon = 1163974960;   // 经度
                gps.alt = 50000;        // 50m
                gps.eph = 20;           // ★ 精度 20cm (非常重要，大了会报错)
                gps.epv = 20;
                gps.satellites_visible = 18; // 18颗星

                mavlink_message_t gpsMsg;
                mavlink_msg_gps_raw_int_encode(1, 1, &gpsMsg, &gps);
                uint16_t gpsLen = mavlink_msg_to_send_buffer(buffer, &gpsMsg);
                emit dataReceived(QByteArray((char*)buffer, gpsLen));
            }

            // --- B. ★★★ 新增：强制伪造 GLOBAL_POSITION_INT ★★★ ---
            // 防止 QGC 因为缺这个包而报错
            {
                mavlink_global_position_int_t gpos;
                memset(&gpos, 0, sizeof(gpos));
                gpos.lat = 399087220;    // 必须和上面一致
                gpos.lon = 1163974960;
                gpos.alt = 50000;        // MSL
                gpos.relative_alt = 10000; // AGL (10m)
                gpos.hdg = 0;            // 北向
                gpos.vx = 0;
                gpos.vy = 0;
                gpos.vz = 0;

                mavlink_message_t gposMsg;
                mavlink_msg_global_position_int_encode(1, 1, &gposMsg, &gpos);
                uint16_t gposLen = mavlink_msg_to_send_buffer(buffer, &gposMsg);
                emit dataReceived(QByteArray((char*)buffer, gposLen));
            }
        }

        // 2. GPS 数据 (Type 3)
        // else if (type == 3) {
        //     int fix = obj.value("fixType").toInt();
        //     int lat = obj.value("lat").toInt();
        //     int lon = obj.value("lon").toInt();
        //     int alt = obj.value("alt").toInt();
        //     int sat = obj.value("count").toInt();
        //     int eph = obj.value("eph").toInt();
        //     int epv = obj.value("epv").toInt();
        //
        //     uint8_t mavFix = 0;
        //     switch(fix) {
        //         case 2: mavFix = 2; break;
        //         case 3: mavFix = 3; break;
        //         case 4: mavFix = 3; break;
        //         case 5: mavFix = 6; break;
        //         case 6: mavFix = 5; break;
        //         default: mavFix = 0; break;
        //     }
        //
        //     mavlink_gps_raw_int_t gps;
        //     memset(&gps, 0, sizeof(gps));
        //     gps.time_usec = 0;
        //     gps.fix_type = mavFix;
        //     gps.lat = lat;
        //     gps.lon = lon;
        //     gps.alt = alt;
        //     gps.eph = (eph == 0) ? 0xFFFF : eph;
        //     gps.epv = (epv == 0) ? 0xFFFF : epv;
        //     gps.vel = 0xFFFF;
        //     gps.cog = 0xFFFF;
        //     gps.satellites_visible = (uint8_t)sat;
        //
        //     mavlink_msg_gps_raw_int_encode(1, 1, &msg, &gps);
        //     uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
        //     emit dataReceived(QByteArray((char*)buffer, len));
        // }

        // 3. 姿态 (Type 9)
        else if (type == 9) {
            float roll = (float)obj.value("roll").toDouble();
            float pitch = (float)obj.value("pitch").toDouble();
            float yaw = (float)obj.value("yaw").toDouble();

            // 如果厂商单位是度，这里需要转弧度
            // float roll = qDegreesToRadians(...);

            mavlink_msg_attitude_pack(1, 1, &msg, 0, roll, pitch, yaw, 0, 0, 0);
            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));
        }

        // 4. 文本消息 (Type 20)
        // else if (type == 20) {
        //     int severity = obj.value("severity").toInt();
        //     QJsonArray textArr = obj.value("text").toArray();
        //     QString rawStr = "";
        //     for(int i=0; i<textArr.size(); i++) rawStr.append(QChar(textArr[i].toInt()));
        //     QString decodedStr = unescapeUnicode(rawStr);
        //
        //     char textBuf[50] = {0};
        //     QByteArray utf8Bytes = decodedStr.toUtf8();
        //     int len = qMin((int)utf8Bytes.size(), 49);
        //     memcpy(textBuf, utf8Bytes.constData(), len);
        //
        //     mavlink_msg_statustext_pack(1, 1, &msg, (uint8_t)severity, textBuf, 0, 0);
        //     uint16_t msgLen = mavlink_msg_to_send_buffer(buffer, &msg);
        //     emit dataReceived(QByteArray((char*)buffer, msgLen));
        // }
    }
}

void BoyingWorker::sendData(const QByteArray bytes)
{
#ifdef Q_OS_ANDROID
    if (!_javaSdk.isValid()) return;

    mavlink_message_t msg;
    mavlink_status_t status;

    for (int i = 0; i < bytes.length(); i++) {
        if (mavlink_parse_char(MAVLINK_COMM_0, (uint8_t)bytes[i], &msg, &status)) {

            // 1. 拦截参数列表请求
            if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_LIST) {
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
                        mavlink_msg_param_value_encode(1, 1, &txMsg, &p);
                        uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                        emit dataReceived(QByteArray((char*)buffer, len));
                        QThread::msleep(30);
                    }
                }, Qt::QueuedConnection);
                continue;
            }
            // 2. 拦截单个参数补发
            else if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_READ) {
                mavlink_param_request_read_t req;
                mavlink_msg_param_request_read_decode(&msg, &req);
                int idx = req.param_index;
                if (idx >= 0 && idx < s_paramCount) {
                     mavlink_message_t txMsg;
                     uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
                     mavlink_param_value_t p;
                     strncpy(p.param_id, s_mockParams[idx].id, 16);
                     p.param_value = s_mockParams[idx].value;
                     p.param_type = s_mockParams[idx].type;
                     p.param_count = s_paramCount;
                     p.param_index = idx;
                     mavlink_msg_param_value_encode(1, 1, &txMsg, &p);
                     uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                     emit dataReceived(QByteArray((char*)buffer, len));
                }
                continue;
            }
            // 3. 拦截航点请求 (回 0)
            else if (msg.msgid == MAVLINK_MSG_ID_MISSION_REQUEST_LIST) {
                mavlink_message_t txMsg;
                uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
                mavlink_msg_mission_count_pack(1, 1, &txMsg, msg.sysid, msg.compid, 0, MAV_MISSION_TYPE_MISSION, 0);
                uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                emit dataReceived(QByteArray((char*)buffer, len));
                continue;
            }

            // 4. 控制指令 (MAVLink -> JSON) + ACK 回复
            QString jsonCmd;
            uint16_t cmd_ack_id = 0;

            if (msg.msgid == MAVLINK_MSG_ID_COMMAND_LONG) {
                mavlink_command_long_t cmd;
                mavlink_msg_command_long_decode(&msg, &cmd);
                cmd_ack_id = cmd.command; // 记录 ID 以便回复 ACK

                if (cmd.command == MAV_CMD_NAV_TAKEOFF) {
                    jsonCmd = QString("{\"byType\":34, \"command\":22, \"param7\":%1}").arg(cmd.param7 > 0 ? cmd.param7 : 5.0);
                }
                else if (cmd.command == MAV_CMD_NAV_LAND) {
                    jsonCmd = QString("{\"byType\":34, \"command\":21}");
                }
                else if (cmd.command == MAV_CMD_COMPONENT_ARM_DISARM) {
                    jsonCmd = QString("{\"byType\":34, \"command\":400, \"param1\":%1}").arg(cmd.param1);
                }
                else if (cmd.command == MAV_CMD_NAV_RETURN_TO_LAUNCH) {
                    jsonCmd = QString("{\"byType\":29, \"base_mode\":1, \"custom_mode\":6}");
                }
                else if (cmd.command == MAV_CMD_DO_SET_MODE) {
                    int px4Mode = (int)cmd.param2;
                    int vendorMode = 5;
                    if(px4Mode == 196608) vendorMode = 2; // Alt
                    else if(px4Mode == 262144) vendorMode = 5; // Pos
                    else if(px4Mode == 67108864) vendorMode = 3; // Mission
                    else if(px4Mode == 84148224) vendorMode = 6; // RTL
                    else if(px4Mode == 50593792) vendorMode = 9; // Land

                    jsonCmd = QString("{\"byType\":29, \"base_mode\":1, \"custom_mode\":%1}").arg(vendorMode);
                }
            }

            // 发送给 JNI 并 回复 ACK
            if (!jsonCmd.isEmpty()) {
                qDebug() << "TX JSON:" << jsonCmd;
                QJniObject jStr = QJniObject::fromString(jsonCmd);
                QJniObject jBytesObj = _javaSdk.callObjectMethod(
                    "GetByteByJsonJava", "(Ljava/lang/String;)[B", jStr.object<jstring>()
                );

                bool success = false;
                if (jBytesObj.isValid()) {
                    jbyteArray jBytes = jBytesObj.object<jbyteArray>();

                    QJniObject::callStaticMethod<void>(
                        "org/qjkj/gcs/QGCConnectionManager",
                        "sendData", "([B)V", jBytes
                    );
                    success = true;
                }

                // ★★★ 核心修复：发送 ACK ★★★
                if (success && cmd_ack_id != 0) {
                     mavlink_message_t ackMsg;
                     uint8_t ackBuf[MAVLINK_MAX_PACKET_LEN];
                     mavlink_msg_command_ack_pack(
                        1, 1, &ackMsg,
                        cmd_ack_id, MAV_RESULT_ACCEPTED,
                        255, 0, msg.sysid, msg.compid);
                     uint16_t ackLen = mavlink_msg_to_send_buffer(ackBuf, &ackMsg);
                     emit dataReceived(QByteArray((char*)ackBuf, ackLen));
                     qDebug() << " ACK Sent for Command:" << cmd_ack_id;
                }
            }
        }
    }
#endif
}

void BoyingWorker::cleanup()
{
#ifdef Q_OS_ANDROID
    // 1. 先停止 Java 业务 (耗时操作，放在锁外面，防止死锁)
    // 只要 SDK 对象有效就尝试停止，不需要依赖 s_isSdkInitialized 标志
    if (_javaSdk.isValid()) {
        // 增加 JNI 异常检查，防止停止时 Java 抛异常导致 C++ 崩溃
        QJniEnvironment env;
        _javaSdk.callMethod<jint>("StopSDKJava", "()I");

        // 如果停止过程中 Java 报错，清除异常继续执行，不要崩
        if (env.checkAndClearExceptions()) {
            qWarning() << "BoyingWorker: Exception ignored during StopSDKJava";
        }
    }

    // 2. ★★★ 加锁切断回调 ★★★
    // 这一步是防止崩溃的核心
    {
        QMutexLocker locker(&s_workerMutex);

        // QPointer 的标准清空方式 (或者 s_worker = nullptr 也可以)
        s_worker.clear();

        s_isSdkInitialized = false;
    }

    // 3. 清理定时器
    if (_heartbeatTimer) {
        _heartbeatTimer->stop();
        delete _heartbeatTimer;
        _heartbeatTimer = nullptr;
    }

    qDebug() << "BoyingWorker: Cleanup finished.";
#endif
}
BoyingLink::BoyingLink(SharedLinkConfigurationPtr& config) : LinkInterface(config), _is_connected(false), _thread(nullptr), _worker(nullptr) {}
BoyingLink::~BoyingLink() { disconnect(); }

bool BoyingLink::isConnected(void) const { return _is_connected; }

bool BoyingLink::_connect(void) {
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
    if (_worker) {
        // 1. 通知 Worker 清理资源 (JNI stop)
        emit _workerCleanup();
    }

    if (_thread) {
        // 2. 告诉线程退出
        _thread->quit();

        // 3. ★★★ 必须等待线程完全停止！否则会崩！★★★
        // 给它 2 秒钟时间退出，如果超时强行杀掉
        if (!_thread->wait(2000)) {
            _thread->terminate();
        }

        delete _thread;
        _thread = nullptr;
        _worker = nullptr; // Worker 会被线程的 deleteLater 自动删除
    }

    if (_is_connected) {
        _is_connected = false;
        emit disconnected();
    }
}

void BoyingLink::_writeBytes(const QByteArray& bytes) { if (_is_connected) emit _workerSend(bytes); }
void BoyingLink::_onWorkerData(QByteArray data) { emit bytesReceived(this, data); }