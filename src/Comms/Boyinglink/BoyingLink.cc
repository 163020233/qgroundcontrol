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
#include <QPointer> //  必须加
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
static QPointer<BoyingWorker> s_worker; //  使用 QPointer



extern "C" {
    // 对应 Java: public static native void nativeOnJsonReceived(String jsonStr);
    JNIEXPORT void JNICALL
    Java_org_qjkj_gcs_QGCConnectionManager_nativeOnJsonReceived(JNIEnv *env, jclass, jstring jsonStr) {
        if (!s_worker) return;

        // 1. 将 Java String 转换为 C++ QString
        const char *nativeString = env->GetStringUTFChars(jsonStr, nullptr);

        if (nativeString) {
            QString qJsonStr = QString::fromUtf8(nativeString);

            // 2. 释放 JNI 字符串引用 (重要！防止内存泄漏)
            env->ReleaseStringUTFChars(jsonStr, nativeString);

            // 3. 线程安全地交给 Worker 处理
            QMetaObject::invokeMethod(s_worker,
                                      "onJsonReceived",        // 调用下面实现的槽函数
                                      Qt::QueuedConnection,
                                      Q_ARG(QString, qJsonStr));
        }
    }
}

// extern "C" {
//     JNIEXPORT void JNICALL
    // Java_org_qjkj_gcs_QGCConnectionManager_nativeOnDataReceived(JNIEnv *env, jclass, jbyteArray data, jint len) {
    //
    //     QMutexLocker locker(&s_workerMutex);
    //
    //     //  QPointer 检查：如果对象已销毁，s_worker 会自动变为 null，绝对安全
    //     if (s_worker.isNull()) {
    //         // qDebug() << "JNI: Worker is dead, ignoring data.";
    //         return;
    //     }
    //
    //     jbyte* buf = env->GetByteArrayElements(data, NULL);
    //     if (!buf) return;
    //
    //     QByteArray rawData((char*)buf, len);
    //     env->ReleaseByteArrayElements(data, buf, JNI_ABORT);
    //
    //     // 使用 s_worker.data() 获取原始指针
    //     QMetaObject::invokeMethod(s_worker.data(), "onJavaDataReceived", Qt::QueuedConnection, Q_ARG(QByteArray, rawData));
    // }

// }
#endif

// =========================================================
// 虚拟参数表 (用于欺骗 QGC 完成初始化)
// =========================================================
struct MockParam {
    const char* id;
    float value;
    uint8_t type; // 6=INT32, 9=REAL32
};

bool needStrictAck(uint16_t cmd) {
    switch (cmd) {
        case MAV_CMD_COMPONENT_ARM_DISARM:
        case MAV_CMD_NAV_TAKEOFF:
        case MAV_CMD_NAV_LAND:
            return true;
        default:
            return false;
    }
}

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
// BoyingWorker 实现 初始化
// =========================================================

void BoyingWorker::init()
{
#ifdef Q_OS_ANDROID
    {
        QMutexLocker locker(&s_workerMutex);
        s_worker = this;
    }

    qDebug() << "BoyingWorker: Initializing Hybrid Link...";

    // 2. 【无锁阶段】：执行耗时的 JNI 操作
    // 此时如果有数据回调进来，nativeOnDataReceived 可以获取到锁，也能用到 s_worker

    _javaSdk = QJniObject("boying/sdk/BoyingSdk");

    if (!_javaSdk.isValid()) {
        qCritical() << "BoyingSdk class not found!";
        return;
    }

    // jint retInit = _javaSdk.callMethod<jint>("InitSDKJava", "()I");
    // _javaSdk.callMethod<jint>("StartSDKJava", "()I");

    QJniObject::callStaticMethod<void>(
        "org/qjkj/gcs/QGCConnectionManager",
        "initConnection",
        "()V"
    );
    qDebug() << "Hybrid Link Initialized!";
    // 3. 【第二阶段加锁】：更新初始化标记
    // QMutexLocker locker(&s_workerMutex);
    // {
    //
    //     // s_isSdkInitialized = true;
    // }
    _parameters["MAV_TYPE"] = 2.0f;
    _parameters["MAV_AUTOPILOT"] = 3.0f; // 标记为 ArduPilot 身份
    _parameters["BAT_N_CELLS"] = 12.0f;  // 针对你的 50V 环境预设

    qDebug() << "Hybrid Link Initialized!";

    // --- [新增] 初始化心跳定时器 ---
    if (!_heartbeatTimer) {
        _heartbeatTimer = new QTimer(this);
        connect(_heartbeatTimer, &QTimer::timeout, this, &BoyingWorker::_sendHeartbeat);
        _heartbeatTimer->start(1000); // 1秒一次
    }

    qDebug() << "Heartbeat timer started at 1Hz";


#endif
}

void BoyingWorker::onJsonReceived(const QString& jsonStr)
{
#ifdef Q_OS_ANDROID
    if (jsonStr.isEmpty()) return;

    // 调试日志：看看收到了什么
    // qDebug() << "RX JSON:" << jsonStr;

    // 直接调用解析逻辑
    _processJsonData(jsonStr);
#endif
}

// 在 BoyingWorker 内部建立一个统一的“真数采集”函数
void BoyingWorker::harvestParam(const QString& id, float value) {
    // 1. 检查值是否发生了变化 (或者 Map 里还没这个参数)
    // 这样可以避免高频重复发送相同的数据，节省带宽
    // 特殊处理：强制电芯数为 12 (针对工业机)
    if (id == "BAT_N_CELLS" && value > 11 && value < 14) {
        value = 12.0f;
    }

    if (!_parameters.contains(id) || _parameters[id] != value) {

        // 2. 将数据填入 Map (这就是数据的“填入”点)
        _parameters[id] = value;

        // 3. 立即构造一个 PARAM_VALUE 消息主动推送到 QGC
        // 这样 QGC 的 UI（如电池图标、参数表）会立刻跳动更新
        mavlink_message_t pMsg;
        uint8_t buf[MAVLINK_MAX_PACKET_LEN];

        mavlink_msg_param_value_pack(
            1, 1, &pMsg,
            id.toLatin1().data(), // 参数 ID
            value,                 // 参数真实值
            MAV_PARAM_TYPE_REAL32, // 统一用 float 类型
            _parameters.size(),    // 当前参数总数
            -1                     // 索引设为 -1 代表这是“主动更新”
        );

        uint16_t len = mavlink_msg_to_send_buffer(buf, &pMsg);
        emit dataReceived(QByteArray((char*)buf, len));

        qDebug() << "采集到真实参数并同步:" << id << "=" << value;
    }
}

// 辅助函数：专门负责把数据发给 QGC 界面显示
void BoyingWorker::sendNamedValue(const char* name, float value) {
    mavlink_message_t msg;
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

    // MAVLink 标准具名数值包 (ID #242)
    // 这个包的设计初衷就是为了让开发者不改源码就能给 UI 传自定义数据
    mavlink_msg_named_value_float_pack(
        1,                         // System ID
        1,                         // Component ID
        &msg,                      // 消息对象
        QDateTime::currentMSecsSinceEpoch(), // 时间戳
        name,                      // 名字 (最多10字符，如 "Vol")
        value                      // 数值
    );

    // 将打包好的字节流通过信号发送给 LinkInterface
    uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
    emit dataReceived(QByteArray((char*)buffer, len));

    // 工业级调试建议：如果想确认数据发出了   日志
    // qDebug() << "Telemetry Push ->" << name << ":" << value;
}


//模式与心跳分拣模块
void BoyingWorker::handleModePacket(const QJsonObject& obj) {
    int customMode = obj.value("custom_mode").toInt();
    int baseMode   = obj.value("base_mode").toInt();
    int sysStatus  = obj.value("system_status").toInt();

    // 映射逻辑
    uint32_t arduMode = 0;
    switch (customMode) {
        case 2:  arduMode = 2; break; // AltHold
        case 5:  case 17: arduMode = 5; break; // Loiter/Hover
        case 6:  arduMode = 6; break; // RTL
        case 3:  arduMode = 3; break; // Auto
        default: arduMode = 0; break;
    }

    // 更新缓存，由 1Hz 定时器发送
    _lastArduMode = arduMode;
    _lastMavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
    if (baseMode & 128) _lastMavBaseMode |= MAV_MODE_FLAG_SAFETY_ARMED;

    if (sysStatus == 4)      _lastMavState = MAV_STATE_ACTIVE;
    else if (sysStatus == 5) _lastMavState = MAV_STATE_CRITICAL;
    else                     _lastMavState = MAV_STATE_STANDBY;
}

//电池与系统健康分拣模块
void BoyingWorker::handleBatteryPacket(const QJsonObject& obj) {
    int voltageCv = obj.value("voltage_battery").toInt();
    float vV = (float)voltageCv / 100.0f;
    uint16_t voltageMv = (uint16_t)(voltageCv * 10);

    // 1. 同步参数
    int cells = qRound(vV / 3.7f);
    if (vV > 40.0f && vV < 55.0f) cells = 12;
    harvestParam("BAT_N_CELLS", (float)cells);

    // 2. 计算平滑电量
    int remain = obj.value("battery_remaining").toInt();
    float rawPerc = (remain >= 0 && remain <= 100) ? (float)remain : ((vV/cells-3.6f)/0.6f*100.0f);
    _smoothBatteryPercent = (_smoothBatteryPercent < 0) ? rawPerc : (_smoothBatteryPercent*0.95f + rawPerc*0.05f);
    int8_t displayRemain = (int8_t)qBound(0.0f, _smoothBatteryPercent, 100.0f);

    // 3. 发送遥测消息
    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_sys_status_pack(1, 1, &msg,
        obj.value("onboard_control_sensors_present").toVariant().toUInt(),
        obj.value("onboard_control_sensors_enabled").toVariant().toUInt(),
        obj.value("onboard_control_sensors_health").toVariant().toUInt(),
        (uint16_t)obj.value("load").toInt(), voltageMv, -1, displayRemain, 0, 0, 0, 0, 0, 0,0,0,0);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

//定位信息分拣模块
void BoyingWorker::handleGPSPacket(const QJsonObject& obj) {
    int type = obj.value("byType").toInt();
    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    if (type == 3) { // GPS_RAW_INT
        mavlink_msg_gps_raw_int_pack(1, 1, &msg,
            QDateTime::currentMSecsSinceEpoch()*1000,
            obj.value("fixType").toInt(),
            obj.value("lat").toInt(), obj.value("lon").toInt(), obj.value("alt").toInt(),
            (uint16_t)obj.value("eph").toInt(), (uint16_t)obj.value("epv").toInt(),
            (uint16_t)obj.value("vel").toInt(), (uint16_t)obj.value("cog").toInt(),
            (uint8_t)obj.value("count").toInt(), 0, 0, 0, 0, 0, 0);
    } else if (type == 12) { // GLOBAL_POSITION_INT
        mavlink_msg_global_position_int_pack(1, 1, &msg,
            QDateTime::currentMSecsSinceEpoch(),
            obj.value("lat").toInt(), obj.value("lon").toInt(),
            obj.value("alt").toInt(), obj.value("relative_alt").toInt(),
            (int16_t)obj.value("vx").toInt(), (int16_t)obj.value("vy").toInt(), (int16_t)obj.value("vz").toInt(),
            (uint16_t)obj.value("hdg").toInt());
    }
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

// 姿态与 HUD 分拣模块
void BoyingWorker::handleHUDPacket(const QJsonObject& obj) {
    int type = obj.value("byType").toInt();
    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    if (type == 8) { // VFR_HUD
        mavlink_msg_vfr_hud_pack(1, 1, &msg,
            (float)obj.value("airspeed").toDouble(), (float)obj.value("groundspeed").toDouble(),
            (int16_t)obj.value("heading").toInt(), (uint16_t)obj.value("throttle").toInt(),
            (float)obj.value("alt").toDouble(), (float)obj.value("climb").toDouble());
    } else if (type == 9) { // ATTITUDE
        mavlink_msg_attitude_pack(1, 1, &msg, QDateTime::currentMSecsSinceEpoch(),
            (float)obj.value("roll").toDouble(), (float)obj.value("pitch").toDouble(), (float)obj.value("yaw").toDouble(),
            (float)obj.value("rollspeed").toDouble(), (float)obj.value("pitchspeed").toDouble(), (float)obj.value("yawspeed").toDouble());
    }
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

void BoyingWorker::handleVersionPacket(const QJsonObject& obj) {
    // 1. 处理固件版本 (将 JSON 数组转为字符串)
    QJsonArray verArr = obj.value("firmware_version").toArray();
    QString versionStr;
    for (const auto& v : verArr) {
        int charCode = v.toInt();
        if (charCode == 0) break;
        // 转换逻辑：如果数值大于 255，可能是双字节编码，这里按常规字符处理
        versionStr.append(QChar(charCode));
    }

    // 2. 将版本信息存入参数表，方便查看
    // 注意：MAVLink 参数 ID 最长 16 字节
    // qDebug() << "【固件信息】" << versionStr;

    // 3. 采集工业载荷状态：液位和水泵
    harvestParam("BY_PUMP_PWM", (float)obj.value("pump").toInt());
    harvestParam("BY_LIQ_LEVEL", (float)obj.value("level").toInt());

    // 4. 断点续飞状态记录
    harvestParam("BY_BRK_STAT", (float)obj.value("break_point_status").toInt());

    float pump = (float)obj.value("pump").toInt();
    float level = (float)obj.value("level").toInt();

    // 原有逻辑：存参数
    harvestParam("BY_PUMP_PWM", pump);
    harvestParam("BY_LIQ_LEVEL", level);

    // 【新增逻辑】：让 QGC 屏幕能实时显示水泵功率和药量百分比
    sendNamedValue("Pump", pump);
    sendNamedValue("Level", level);
}

void BoyingWorker::handleServoPacket(const QJsonObject& obj) {
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    // 处理日志中出现的 time_usec 负数问题 (溢出处理)
    int64_t time_usec = (int64_t)obj.value("time_usec").toDouble();
    if (time_usec <= 0) {
        time_usec = QDateTime::currentMSecsSinceEpoch() * 1000;
    }

    // 打包 SERVO_OUTPUT_RAW
    mavlink_msg_servo_output_raw_pack(1, 1, &msg,
        (uint32_t)time_usec,
        (uint8_t)obj.value("port").toInt(),
        (uint16_t)obj.value("servo1_raw").toInt(),
        (uint16_t)obj.value("servo2_raw").toInt(),
        (uint16_t)obj.value("servo3_raw").toInt(),
        (uint16_t)obj.value("servo4_raw").toInt(),
        (uint16_t)obj.value("servo5_raw").toInt(),
        (uint16_t)obj.value("servo6_raw").toInt(),
        (uint16_t)obj.value("servo7_raw").toInt(),
        (uint16_t)obj.value("servo8_raw").toInt(),
        0, 0, 0, 0, 0, 0, 0, 0 // 9-16路暂时补0
    );

    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

void BoyingWorker::handleTimePacket(const QJsonObject& obj) {
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    uint64_t unix_us = (uint64_t)obj.value("time_unix_usec").toDouble();
    // 如果飞控没有 Unix 时间，使用地面站当前时间
    if (unix_us == 0) {
        unix_us = QDateTime::currentMSecsSinceEpoch() * 1000;
    }

    mavlink_msg_system_time_pack(1, 1, &msg,
        unix_us,
        (uint32_t)obj.value("time_boot_ms").toInt()
    );

    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

//中文报警分拣模块
void BoyingWorker::handleTextPacket(const QJsonObject& obj) {
    QJsonArray textArr = obj.value("text").toArray();
    QByteArray rawBytes;
    for(const auto& item : textArr) {
        char c = (char)item.toInt();
        if (c == 0) break;
        rawBytes.append(c);
    }
    QString decodedStr = unescapeUnicode(QString::fromUtf8(rawBytes));
    QByteArray finalBytes = decodedStr.toUtf8().left(49); // MAVLink 限制 50 字节

    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_statustext_pack(1, 1, &msg, (uint8_t)obj.value("severity").toInt(), finalBytes.data(), 0, 0);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));

    qDebug() << "【飞控报警】" << decodedStr;
}

//固件信息分拣模块
void BoyingWorker::handleStaticInfoPacket(const QJsonObject& obj) {
    // 固件版本等信息不需要高频发送，存入参数表即可
    harvestParam("SW_VER", (float)obj.value("fli_con_seq").toInt());
    harvestParam("HW_VER", (float)obj.value("har_pro_bat").toInt());
}

// 载荷控制分拣模块
void BoyingWorker::handlePayloadPacket(const QJsonObject& obj) {
    int type = obj.value("byType").toInt();

    if (type == 14) {
        float sprayFlow = (float)obj.value("command4").toDouble();
        float sprayVol  = (float)obj.value("command5").toDouble();

        // 原有逻辑：存参数
        harvestParam("SPRAY_FLOW", sprayFlow);
        harvestParam("SPRAY_VOL",  sprayVol);

        // 【新增逻辑】：直接给 QGC 屏幕发实时数字
        sendNamedValue("SprayFlow", sprayFlow);
        sendNamedValue("SprayVol",  sprayVol);
    }
    else if (type == 26 || type == 13) {
        float dist = (float)obj.value("diatance").toInt();
        harvestParam("SENS_DIST", dist);
        // 也给屏幕发一个实时距离
        sendNamedValue("RadarDist", dist);
    }
}

// --- 遥控器通道 (Type 22, 25) ---
void BoyingWorker::handleRCChannelsPacket(const QJsonObject& obj) {
    mavlink_rc_channels_t rc; memset(&rc, 0, sizeof(rc));
    rc.time_boot_ms = QDateTime::currentMSecsSinceEpoch();
    rc.chancount = (obj.value("byType").toInt() == 22) ? 18 : 8;
    rc.rssi = (uint8_t)obj.value("rssi").toInt();
    rc.chan1_raw = (uint16_t)obj.value("chan1_raw").toInt();
    rc.chan2_raw = (uint16_t)obj.value("chan2_raw").toInt();
    rc.chan3_raw = (uint16_t)obj.value("chan3_raw").toInt();
    rc.chan4_raw = (uint16_t)obj.value("chan4_raw").toInt();
    rc.chan5_raw = (uint16_t)obj.value("chan5_raw").toInt();
    rc.chan6_raw = (uint16_t)obj.value("chan6_raw").toInt();
    rc.chan7_raw = (uint16_t)obj.value("chan7_raw").toInt();
    rc.chan8_raw = (uint16_t)obj.value("chan8_raw").toInt();

    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_rc_channels_encode(1, 1, &msg, &rc);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

//底层传感器分拣模块
void BoyingWorker::handleRawSensorPacket(const QJsonObject& obj) {
    int type = obj.value("byType").toInt();
    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    if (type == 6) { // SCALED_IMU
        mavlink_msg_scaled_imu_pack(1, 1, &msg, obj.value("time_boot_ms").toInt(),
            (int16_t)obj.value("xacc").toInt(), (int16_t)obj.value("yacc").toInt(), (int16_t)obj.value("zacc").toInt(),
            (int16_t)obj.value("xgyro").toInt(), (int16_t)obj.value("ygyro").toInt(), (int16_t)obj.value("zgyro").toInt(),
            (int16_t)obj.value("xmag").toInt(), (int16_t)obj.value("ymag").toInt(), (int16_t)obj.value("zmag").toInt(), 0);
    } else if (type == 7) { // VIBRATION
        mavlink_msg_vibration_pack(1, 1, &msg, QDateTime::currentMSecsSinceEpoch()*1000,
            (float)obj.value("vibration_x").toDouble(), (float)obj.value("vibration_y").toDouble(), (float)obj.value("vibrationZ").toDouble(),
            obj.value("clipping_0").toInt(), obj.value("clipping_1").toInt(), obj.value("clipping_2").toInt());
    }
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

void BoyingWorker::handleVibrationPacket(const QJsonObject& obj) {
    mavlink_message_t msg; uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_vibration_pack(1, 1, &msg, QDateTime::currentMSecsSinceEpoch()*1000,
        (float)obj.value("vibration_x").toDouble(), (float)obj.value("vibration_y").toDouble(), (float)obj.value("vibrationZ").toDouble(), 0,0,0);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

void BoyingWorker::_processJsonData(const QString& jsonStr)
{
    // 1. JSON 解析逻辑（保持现状）
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) return;

    _isFirstDataReceived = true; // 激活链路标志
    _dataTimeoutTimer.restart(); // 刷新看门狗计时

    QJsonArray msgArray;
    if (doc.isObject()) {
        QJsonObject root = doc.object();
        msgArray = root.contains("msg") ? root.value("msg").toArray() : QJsonArray{root};
    } else {
        msgArray = doc.array();
    }

    // 2. 核心分拣循环
    for (const auto& val : msgArray) {
        QJsonObject obj = val.toObject();
        int type = obj.value("byType").toInt();

        switch (type) {
            case 0:
            case 29: handleModePacket(obj);          break; // 状态机与心跳
            case 2:  handleStaticInfoPacket(obj);    break; // 固件版本
            case 3:
            case 4:  handleGPSPacket(obj);           break; // 双 GPS 冗余
            case 12: handleGPSPacket(obj);           break; // 融合定位
            case 5:  handleBatteryPacket(obj);       break; // 电池平滑滤波
            case 6:  handleRawSensorPacket(obj);     break; // IMU
            case 7:  handleVibrationPacket(obj);     break; // 震动检测
            case 8:
            case 9:  handleHUDPacket(obj);           break; // HUD姿态
            case 11: handleVersionPacket(obj);       break; // 固件/泵/液位
            case 14:
            case 24: handlePayloadPacket(obj);       break; // 【补齐】作业统计
            case 21: handleServoPacket(obj);         break; // 电机输出PWM
            case 22:
            case 25: handleRCChannelsPacket(obj);    break; // 【补齐】18通道RC
            case 23: handleTimePacket(obj);          break; // 系统时间同步
            case 20: handleTextPacket(obj);          break; // 中文语音报警
            case 13:
            case 26: handlePayloadPacket(obj);       break; // 雷达测距
            default: break;
        }
    }
}


void BoyingWorker::_sendHeartbeat() {
    // 逻辑：如果从来没收到过 SDK 数据，或者最近 3 秒都没收到过 SDK 数据
    if (!_isFirstDataReceived || _dataTimeoutTimer.elapsed() > 3000) {
        // 停止向 QGC 汇报，这样 QGC 就会显示“连接断开”
        if (_isFirstDataReceived) {
            qDebug() << "检测到 SDK 数据停流，停止发送心跳";
            _isFirstDataReceived = false; // 重置，等待下次无人机开机
        }
        return;
    }

    // --- 只有链路正常时才执行发包逻辑 ---
    mavlink_message_t msg;
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_heartbeat_pack(1, 1, &msg,
                               MAV_TYPE_QUADROTOR,
                               MAV_AUTOPILOT_ARDUPILOTMEGA,
                               _lastMavBaseMode,
                               _lastArduMode,
                               _lastMavState);

    uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
    emit dataReceived(QByteArray((char*)buffer, len));
}

void BoyingWorker::sendData(const QByteArray bytes)
{
#ifdef Q_OS_ANDROID
    if (!_javaSdk.isValid()) return;

    mavlink_message_t msg;
    mavlink_status_t status;

    for (int i = 0; i < bytes.length(); i++) {
        if (mavlink_parse_char(MAVLINK_COMM_0, (uint8_t)bytes[i], &msg, &status)) {

            // =========================================================
            // 1. 参数协议与航点请求 (保留原有逻辑)
            // =========================================================
            if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_LIST) {
                QMetaObject::invokeMethod(this, [=](){
                    int total = _parameters.size();
                    int index = 0;
                    for (auto it = _parameters.begin(); it != _parameters.end(); ++it) {
                        mavlink_message_t txMsg; uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
                        mavlink_msg_param_value_pack(1, 1, &txMsg, it.key().toLatin1().data(), it.value(), MAV_PARAM_TYPE_REAL32, total, index++);
                        uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                        emit dataReceived(QByteArray((char*)buffer, len));
                        QThread::msleep(15);
                    }
                }, Qt::QueuedConnection);
                continue;
            }
            else if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_READ) {
                mavlink_param_request_read_t req;
                mavlink_msg_param_request_read_decode(&msg, &req);
                QString pId = QString::fromLatin1(req.param_id);
                if (_parameters.contains(pId)) {
                    mavlink_message_t txMsg; uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
                    mavlink_msg_param_value_pack(1, 1, &txMsg, pId.toLatin1().data(), _parameters[pId], MAV_PARAM_TYPE_REAL32, _parameters.size(), req.param_index);
                    uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                    emit dataReceived(QByteArray((char*)buffer, len));
                }
                continue;
            }
            // // 在 sendData 的 MAVLink 循环里拦截
            // if (msg.msgid == MAVLINK_MSG_ID_MISSION_COUNT) {
            //     qDebug() << "警告：现版本QGC 尝试上传航线，但 SDK 暂不支持。";

            //     // 1. 构造一个拒绝消息 (MISSION_ACK)
            //     mavlink_message_t ackMsg;
            //     uint8_t ackBuf[MAVLINK_MAX_PACKET_LEN];

            //     // 类型设为 MAV_MISSION_UNSUPPORTED
            //     //mavlink_msg_mission_ack_pack(1, 1, &ackMsg,
            //                                  msg.sysid, msg.compid,
            //                                  MAV_MISSION_UNSUPPORTED,
            //                                  MAV_MISSION_TYPE_MISSION);

            //     uint16_t len = mavlink_msg_to_send_buffer(ackBuf, &ackMsg);
            //     emit dataReceived(QByteArray((char*)ackBuf, len));

            //             // 2. 屏幕提示操作员
            //    // reportToUser("当前固件暂不支持航点上传", MAV_SEVERITY_WARNING);

            //     continue; // 处理完毕，跳过该包
            // }

            else if (msg.msgid == MAVLINK_MSG_ID_PARAM_SET) {
                mavlink_param_set_t set;
                mavlink_msg_param_set_decode(&msg, &set);
                QString pId = QString::fromLatin1(set.param_id);
                _parameters[pId] = set.param_value;
                QString jsonCmd;
                if (pId == "RTL_RETURN_ALT") jsonCmd = QString("{\"byCommand\":\"SetRTLAlt\",\"value\":%1}").arg(set.param_value);
                if (!jsonCmd.isEmpty()) {
                    QJniObject jStr = QJniObject::fromString(jsonCmd);
                    QJniObject::callStaticMethod<jint>("org/qjkj/gcs/QGCConnectionManager", "sendDataWithResult", "(Ljava/lang/String;)I", jStr.object<jstring>());
                }
                mavlink_message_t txMsg; uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
                mavlink_msg_param_value_pack(1, 1, &txMsg, set.param_id, set.param_value, set.param_type, _parameters.size(), -1);
                uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                emit dataReceived(QByteArray((char*)buffer, len));
                continue;
            }
            else if (msg.msgid == MAVLINK_MSG_ID_MISSION_REQUEST_LIST) {
                mavlink_message_t txMsg; uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
                mavlink_msg_mission_count_pack(1, 1, &txMsg, msg.sysid, msg.compid, 0, MAV_MISSION_TYPE_MISSION, 0);
                uint16_t len = mavlink_msg_to_send_buffer(buffer, &txMsg);
                emit dataReceived(QByteArray((char*)buffer, len));
                continue;
            }

                    // =========================================================
                    // 2. 控制指令翻译 (针对 ArduPilot 模式 ID 进行适配)
                    // =========================================================
            QString jsonCmd;
            uint16_t cmd_ack_id = 0;
            uint16_t command = 0;
            float p1=0, p2=0, p7=0;
            double lat=0, lon=0;

            if (msg.msgid == MAVLINK_MSG_ID_COMMAND_LONG) {
                mavlink_command_long_t cmd;
                mavlink_msg_command_long_decode(&msg, &cmd);
                command = cmd.command; p1 = cmd.param1; p2 = cmd.param2; p7 = cmd.param7;
                lat = cmd.param5; lon = cmd.param6;
            } else if (msg.msgid == MAVLINK_MSG_ID_COMMAND_INT) {
                mavlink_command_int_t cmd;
                mavlink_msg_command_int_decode(&msg, &cmd);
                command = cmd.command; p1 = cmd.param1; p2 = cmd.param2; p7 = cmd.z;
                lat = (double)cmd.x / 1.0e7; lon = (double)cmd.y / 1.0e7;
            }

            if (command != 0) {
                cmd_ack_id = command;

                        // 自动回复 512 (消息请求)
                if (command == 512 && (int)p1 == 280) {
                    char text[] = "System Ready";
                    mavlink_message_t txtMsg; uint8_t txtBuf[MAVLINK_MAX_PACKET_LEN];
                    mavlink_msg_statustext_pack(1, 1, &txtMsg, MAV_SEVERITY_INFO, text, 0, 0);
                    uint16_t txtLen = mavlink_msg_to_send_buffer(txtBuf, &txtMsg);
                    emit dataReceived(QByteArray((char*)txtBuf, txtLen));
                }

                // --- A. 起飞 ---
                else if (command == MAV_CMD_NAV_TAKEOFF) {
                    jsonCmd = QString("{\"byCommand\":\"TakeOff\",\"alt\":%1}").arg(p7 > 0 ? p7 : 5.0f);
                }
                // --- B. 降落 ---
                else if (command == MAV_CMD_NAV_LAND) {
                    jsonCmd = QString("{\"byCommand\":\"Land\"}");
                }
                // --- C. 解锁/上锁 ---
                else if (command == MAV_CMD_COMPONENT_ARM_DISARM) {
                    jsonCmd = QString("{\"byCommand\":\"%1\"}").arg(p1 > 0.5f ? "DisArm" : "Arm");
                }
                // --- D. 返航指令 (直接指令) ---
                else if (command == MAV_CMD_NAV_RETURN_TO_LAUNCH) {
                    jsonCmd = QString("{\"byCommand\":\"ReturnBack\"}");
                }
                // --- E. 指点飞行 ---
                else if (command == MAV_CMD_DO_REPOSITION) {
                    jsonCmd = QString("{\"byCommand\":\"PointingFlight\",\"speed\":%1,\"alt\":%2,\"lat\":%3,\"lon\":%4}")
                    .arg(p2 > 0 ? p2 : 5.0f).arg(p7 != 0 ? p7 : 10.0f).arg(lat,0,'f',7).arg(lon,0,'f',7);
                }
                // 在 sendData 的指令解析部分增加
                // 在 BoyingWorker::sendData 函数的指令解析 switch/if-else 块中增加：
                //舵机
                else if (command == MAV_CMD_DO_SET_SERVO) {
                    int servoIndex = (int)p1; // 舵机序号
                    int pwmValue   = (int)p2; // PWM值 (通常 1000-2000)

                    qDebug() << "收到 QGC 舵机指令: 序号" << servoIndex << " PWM:" << pwmValue;

                            // 工业级业务映射：假设我们将 9 号舵机定义为抛投器
                    if (servoIndex == 9) {
                        if (pwmValue > 1500) {
                            // PWM 大于 1500 视为“执行释放”
                            jsonCmd = "{\"byCommand\":\"ReleasePayload\",\"id\":1}";
                            // reportToUser("【载荷】正在执行抛投...", MAV_SEVERITY_NOTICE);
                        } else {
                            // PWM 小于 1500 视为“复位/锁定”
                            jsonCmd = "{\"byCommand\":\"LockPayload\",\"id\":1}";
                            // reportToUser("【载荷】抛投器已复位", MAV_SEVERITY_NOTICE);
                        }
                    }

                    // 【关键】记录此 ID，稍后回发 ACK
                    cmd_ack_id = command;
                }
                // --- F. 模式切换 (核心修改点：使用 ArduPilot ID) ---
                else if (command == MAV_CMD_DO_SET_MODE) {
                    int arduMode = (int)p2;
                    if (arduMode == 17) {
                        // QGC 点了“暂停”
                        jsonCmd = "{\"byCommand\":\"Hover\"}"; // 映射为博盈的悬停
                    }else if (arduMode == 6) {      // ArduPilot RTL ID
                        jsonCmd = "{\"byCommand\":\"ReturnBack\"}";
                    } else if (arduMode == 2) { // ArduPilot AltHold ID
                        jsonCmd = "{\"byCommand\":\"Hover\"}";
                    } else if (arduMode == 5) { // ArduPilot Loiter ID
                        jsonCmd = "{\"byCommand\":\"Hover\"}";
                    } else if (arduMode == 3) { // ArduPilot Auto ID
                        jsonCmd = "{\"byCommand\":\"AutonomousWork\"}";
                    } else {
                        jsonCmd = "{\"byCommand\":\"Hover\"}";
                    }
                }
            }

                    // =========================================================
                    // 4. JNI 发送与 ACK 回复 (确保 QGC 状态机闭环)
                    // =========================================================
            if (!jsonCmd.isEmpty()) {
                qDebug() << "TX JSON:" << jsonCmd;
                QJniObject jStr = QJniObject::fromString(jsonCmd);
                jint sdkResult = QJniObject::callStaticMethod<jint>("org/qjkj/gcs/QGCConnectionManager",
                                                                    "sendDataWithResult", "(Ljava/lang/String;)I", jStr.object<jstring>());

                if (cmd_ack_id != 0) {
                    MAV_RESULT res = MAV_RESULT_ACCEPTED;
                    if (needStrictAck(cmd_ack_id)) {
                        if (sdkResult > 0) res = MAV_RESULT_TEMPORARILY_REJECTED; // 未返回0 指令执行失败，后续可优化失败具体信息
                        else if (sdkResult < 0) res = MAV_RESULT_FAILED;
                    }
                    mavlink_message_t ackMsg; uint8_t ackBuf[MAVLINK_MAX_PACKET_LEN];
                    mavlink_msg_command_ack_pack(1, 1, &ackMsg, cmd_ack_id, res, 255, 0, msg.sysid, msg.compid);
                    uint16_t ackLen = mavlink_msg_to_send_buffer(ackBuf, &ackMsg);
                    emit dataReceived(QByteArray((char*)ackBuf, ackLen));
                    qDebug() << "ACK Sent for Cmd:" << cmd_ack_id << " Result:" << res;
                }
            }
        }
    }
#endif
}

void BoyingWorker::cleanup()
{
#ifdef Q_OS_ANDROID

    // --- [新增] 停止定时器 ---
    if (_heartbeatTimer) {
        _heartbeatTimer->stop();
        _heartbeatTimer->deleteLater();
        _heartbeatTimer = nullptr;
    }


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

    QJniObject::callStaticMethod<void>(
        "org/qjkj/gcs/QGCConnectionManager",
        "stopConnection",
        "()V"
    );
    // 2.  加锁切断回调

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

bool BoyingLink::_connect(void)
{
    // 1. 如果已经连接，直接返回
    if (_is_connected) {
        return true;
    }

    qDebug() << "BoyingLink: Starting connection thread...";

    // 2. 创建子线程和 Worker
    _thread = new QThread(this);
    _worker = new BoyingWorker(); // 注意：不能设置 Parent，否则无法移动线程

    // 3. 将 Worker 移动到子线程
    _worker->moveToThread(_thread);

    // 4.  绑定信号槽 (主线程 <-> 子线程)

    // 控制信号：Link 通知 Worker 做事
    connect(this, &BoyingLink::_workerInit,    _worker, &BoyingWorker::init);
    connect(this, &BoyingLink::_workerSend,    _worker, &BoyingWorker::sendData);
    connect(this, &BoyingLink::_workerCleanup, _worker, &BoyingWorker::cleanup);

    // 数据信号：Worker 解析完 MAVLink 后传回给 Link
    connect(_worker, &BoyingWorker::dataReceived, this, &BoyingLink::_onWorkerData);

    // 5. 线程生命周期管理 (线程结束时自动删除对象)
    connect(_thread, &QThread::finished, _worker, &QObject::deleteLater);
    connect(_thread, &QThread::finished, _thread, &QObject::deleteLater);

    // 6. 启动线程
    _thread->start();

    // 7. 发送初始化信号 (触发 BoyingWorker::init -> JNI Init)
    emit _workerInit();

    // 8. 更新状态并通知 QGC 核心
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

        // 3.必须等待线程完全停止！否则会崩
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

void BoyingLink::_writeBytes(const QByteArray& bytes)
{
    //  加这行日志
    // qDebug() << "[BoyingLink] QGC trying to send bytes, len:" << bytes.length();

    if (_is_connected) {
        emit _workerSend(bytes);
    } else {
        qWarning() << "[BoyingLink] Dropped bytes because link is disconnected";
    }
}
void BoyingLink::_onWorkerData(QByteArray data) { emit bytesReceived(this, data); }
