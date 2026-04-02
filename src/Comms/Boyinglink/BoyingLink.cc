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



void BoyingWorker::reportToUser(const QString& text, int severity) {
    mavlink_message_t msg;
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

    // 1. 将文字转换为 UTF-8 编码
    QByteArray bytes = text.toUtf8();

    // 2. MAVLink STATUSTEXT 协议限制每条消息最大 50 个字节
    char cText[50] = {0};
    int lenToCopy = qMin(bytes.size(), 49);
    memcpy(cText, bytes.constData(), lenToCopy);

    // 3. 打包 MAVLink 消息 (ID #253)
    mavlink_msg_statustext_pack(
        1,              // System ID
        1,              // Component ID
        &msg,           // 消息对象指针
        (uint8_t)severity,
        cText,          // 文本数组
        0,              // id (用于分片消息，这里填0)
        0               // chunk_seq (用于分片消息，这里填0)
    );

    // 4. 发送字节流
    uint16_t msgLen = mavlink_msg_to_send_buffer(buffer, &msg);
    emit dataReceived(QByteArray((char*)buffer, msgLen));
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

    _parameters.clear();

    // 用这两个参数占位，既能实现秒连，又对系统有好处
    _parameters["SDK_VERSION"] = 1.0f;  // 让用户知道你的网关版本
    _parameters["BAT_N_CELLS"] = 12.0f; // 告诉 QGC

    _lastEph = 99.0f;  // 默认精度极差
    _lastGpsCount = 0; // 默认无卫星
    _lastLat = 0;
    _lastLon = 0;
    _isHomeSet = false; // 初始为未锁定
    _homeLat = 0;
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

    qDebug().noquote() <<QJsonDocument::fromJson(jsonStr.toUtf8())
                              .toJson(QJsonDocument::Compact);
    // // 调试日志：看看收到了什么
    //  qDebug() << "RX JSON:" << jsonStr;

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

    // 逻辑：利用上行字典，将博盈状态翻译给 QGC
    _lastArduMode = customMode;


    // 解锁位判定
    if ((baseMode & 128) == 128) {
        _lastMavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED | MAV_MODE_FLAG_SAFETY_ARMED;
    } else {
        _lastMavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
    }

    // 系统状态同步
    if (sysStatus == 4) {
        _lastMavState = MAV_STATE_ACTIVE;
    } else if (sysStatus == 5) {
        _lastMavState = MAV_STATE_CRITICAL;
    } else {
        _lastMavState = MAV_STATE_STANDBY;
    }
}

//电池与系统健康分拣模块
void BoyingWorker::handleBatteryPacket(const QJsonObject& obj) {
    // 1. 【电压提取】：5016 cV -> 50.16 V
    int voltageCv = obj.value("voltage_battery").toInt();
    float vV = (float)voltageCv / 100.0f;
    uint16_t voltageMv = (uint16_t)(voltageCv * 10);

    // 2. 【电量计算逻辑】：解决飞控报 -1 的问题
    int remainFromSdk = obj.value("battery_remaining").toInt();
    float calculatedPerc = 0.0f;

    if (remainFromSdk >= 0 && remainFromSdk <= 100) {
        // 如果 SDK 以后能报出 0-100 的值，直接用
        calculatedPerc = (float)remainFromSdk;
    } else {
        // --- 核心算术逻辑：针对 12S (50V) 电池组进行换算 ---
        // 50.4V 对应 100%，43.2V 对应 0%
        float minV = 43.2f;
        float maxV = 50.4f;

        calculatedPerc = ((vV - minV) / (maxV - minV)) * 100.0f;
        // 限制在 0-100 范围内
        calculatedPerc = qBound(0.0f, calculatedPerc, 100.0f);
    }

    // 3. 【平滑滤波】：解决 92/93 来回跳动的问题
    // 逻辑：新数据只占 5% 权重，让数字平稳下降
    if (_smoothBatteryPercent < 0) {
        _smoothBatteryPercent = calculatedPerc;
    } else {
        _smoothBatteryPercent = (_smoothBatteryPercent * 0.95f) + (calculatedPerc * 0.05f);
    }
    int8_t displayRemain = (int8_t)qRound(_smoothBatteryPercent);

    // 4. 【参数同步】：告诉 QGC 这是 12S 电池，确保图标不报红
    harvestParam("BAT_N_CELLS", 12.0f);

    // 5. 【发送 MAVLink 消息】
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    // 发送 SYS_STATUS (#1) - 19个参数对齐
    mavlink_msg_sys_status_pack(1, 1, &msg,
        obj.value("onboard_control_sensors_present").toVariant().toUInt(),
        obj.value("onboard_control_sensors_enabled").toVariant().toUInt(),
        obj.value("onboard_control_sensors_health").toVariant().toUInt(),
        (uint16_t)obj.value("load").toInt(),
        voltageMv,
        (int16_t)obj.value("current_battery").toInt(), // 65535 转为 -1
        displayRemain, // 发送计算并滤波后的百分比
        0, 0, 0, 0, 0, 0, 0, 0, 0
    );
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));

    // 发送 BATTERY_STATUS (#147) - 17个参数对齐 (QGC 渲染图标核心)
    uint16_t vArr[10] = {voltageMv, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535};
    mavlink_message_t batMsg;
    mavlink_msg_battery_status_pack(1, 1, &batMsg,
        0, 1, 3, 2500, vArr, -1, -1, -1, displayRemain, 0, 1, nullptr, 0, 0);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &batMsg)));

    // 6. 同步到你自定义的 QML 仪表盘
    sendNamedValue("BatV", vV);
    sendNamedValue("BatP", (float)displayRemain);
}

//定位信息分拣模块
void BoyingWorker::handleGPSPacket(const QJsonObject& obj) {
    int byType = obj.value("byType").toInt();
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    // --- 1. 基础变量提取与清洗 ---
    int32_t  lat       = obj.value("lat").toInt();     // *1E7
    int32_t  lon       = obj.value("lon").toInt();     // *1E7
    int32_t  alt       = obj.value("alt").toInt();     // mm
    int      sdkFix    = obj.value("fixType").toInt();
    uint8_t  sats      = (uint8_t)obj.value("count").toInt();
    uint64_t time_usec = (uint64_t)obj.value("time_usec").toDouble();
    if (time_usec == 0) time_usec = QDateTime::currentMSecsSinceEpoch() * 1000;

    // --- 2. 异常精度数据清洗 (防止 7.2 亿脏数据导致显示为 0) ---
    double rawEph = obj.value("eph").toDouble();
    double rawEpv = obj.value("epv").toDouble();
    // 如果超过 uint16 范围，设为 65535 代表无效，或设为 0 代表忽略
    uint16_t safeEph = (rawEph > 65534 || rawEph < 0) ? 0xFFFF : (uint16_t)rawEph;
    uint16_t safeEpv = (rawEpv > 65534 || rawEpv < 0) ? 0xFFFF : (uint16_t)rawEpv;

    // 更新全局精度记录 (单位：米)
    _lastEph = (float)safeEph / 100.0f;

    // --- 3. 坐标缓存逻辑 (解决 Type 12 经纬度为 0 的 Bug) ---
    if (lat != 0 && lon != 0) {
        _lastLat = lat;
        _lastLon = lon;
    }

    // --- 4. 模式映射：博盈 fixType -> MAVLink fixType ---
    uint8_t mavFix = 0;
    switch (sdkFix) {
        case 2:  mavFix = 2; break;
        case 3:  case 4: mavFix = 3; break;
        case 5:  mavFix = 6; break; // RTK Fixed
        case 6:  mavFix = 5; break; // RTK Float
        default: mavFix = (sdkFix > 0) ? 1 : 0; break;
    }

    // --- 5. 分拣并发送遥测包 ---
    if (byType == 3) { // 主 GPS 数据包
        _lastGpsCount = sats; // 更新全局星数，供解锁逻辑检查

        mavlink_msg_gps_raw_int_pack(1, 1, &msg,
            time_usec, mavFix, lat, lon, alt,
            safeEph, safeEpv,
            (uint16_t)obj.value("vel").toInt(), (uint16_t)obj.value("cog").toInt(),
            sats, 0, 0, 0, 0, 0, 0);
        emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
    }
    else if (byType == 12) { // 融合定位数据包
        // 如果 Type 12 坐标是 0，则借用之前缓存的有效坐标，防止地图闪烁
        int32_t finalLat = (lat == 0) ? _lastLat : lat;
        int32_t finalLon = (lon == 0) ? _lastLon : lon;

        if (finalLat != 0) { // 只有坐标真正有效才发
            mavlink_msg_global_position_int_pack(1, 1, &msg,
                (uint32_t)QDateTime::currentMSecsSinceEpoch(),
                finalLat, finalLon, alt,
                (int32_t)obj.value("relative_alt").toInt(), // 解决 400 米高度问题的核心
                (int16_t)obj.value("vx").toInt(), (int16_t)obj.value("vy").toInt(), (int16_t)obj.value("vz").toInt(),
                (uint16_t)obj.value("hdg").toInt());
            emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
        }
    }

    // --- 6. 【核心】家点自动锁定 (严格匹配 14 个参数接口) ---
    if (mavFix >= 3 && !_isHomeSet && _lastLat != 0) {
        _isHomeSet = true;
        _homeLat = _lastLat; _homeLon = _lastLon; _homeAlt = alt;

        mavlink_message_t hMsg;
        uint8_t hBuf[MAVLINK_MAX_PACKET_LEN];

        // 按照你提供的 14 参数定义填入
        mavlink_msg_home_position_pack(
            1, 1, &hMsg,
            _lastLat,           // 4. 纬度
            _lastLon,           // 5. 经度
            alt,                // 6. 海拔 mm
            0, 0, 0,            // 7,8,9. x,y,z
            nullptr,            // 10. q 指针
            0, 0, 0,            // 11,12,13. approach_x,y,z
            time_usec           // 14. time_usec
        );

        emit dataReceived(QByteArray((char*)hBuf, mavlink_msg_to_send_buffer(hBuf, &hMsg)));
        reportToUser("家点位置已自动锁定", 6); // 6 = MAV_SEVERITY_INFO
    }
}

// 姿态与 HUD 分拣模块
void BoyingWorker::handleHUDPacket(const QJsonObject& obj) {
    int byType = obj.value("byType").toInt();
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    bool shouldSend = false;

    // =========================================================
    // 1. 处理 HUD 基础飞行数据 (Type 8)
    // =========================================================
    if (byType == 8) {
        float    airspeed    = (float)obj.value("airspeed").toDouble();
        float    groundspeed = (float)obj.value("groundspeed").toDouble();
        float    alt         = (float)obj.value("alt").toDouble();
        float    climb       = (float)obj.value("climb").toDouble();
        uint16_t throttle    = (uint16_t)obj.value("throttle").toInt();
        // 关键点：使用你日志里发现的真实 heading 字段
        int16_t  heading     = (int16_t)obj.value("heading").toInt();

        // 打包 MAVLink VFR_HUD (#74)
        mavlink_msg_vfr_hud_pack(1, 1, &msg,
            airspeed,
            groundspeed,
            heading,
            throttle,
            alt,
            climb);

        // --- 同步到自定义 QML 仪表盘面板 ---
        sendNamedValue("Alt",     alt);         // 高度(m)
        sendNamedValue("GSpd",    groundspeed); // 地速(m/s)
        sendNamedValue("Hdg",     (float)heading);
        sendNamedValue("Thr",     (float)throttle);

        shouldSend = true;
    }

    // =========================================================
    // 2. 处理 3D 姿态数据 (Type 9)
    // =========================================================
    else if (byType == 9) {
        // 提取弧度数据 (博盈和 MAVLink 均为 rad，直接透传)
        float roll       = (float)obj.value("roll").toDouble();
        float pitch      = (float)obj.value("pitch").toDouble();
        float yaw        = (float)obj.value("yaw").toDouble();
        float rollspeed  = (float)obj.value("rollspeed").toDouble();
        float pitchspeed = (float)obj.value("pitchspeed").toDouble();
        float yawspeed   = (float)obj.value("yawspeed").toDouble();

        // 打包 MAVLink ATTITUDE (#30)
        mavlink_msg_attitude_pack(1, 1, &msg,
            (uint32_t)QDateTime::currentMSecsSinceEpoch(),
            roll,
            pitch,
            yaw,
            rollspeed,
            pitchspeed,
            yawspeed);

        // --- 转换并同步到自定义 QML 面板 (操作员习惯看角度而非弧度) ---
        float rollDeg  = qRadiansToDegrees(roll);
        float pitchDeg = qRadiansToDegrees(pitch);
        float yawDeg   = qRadiansToDegrees(yaw);
        if (yawDeg < 0) yawDeg += 360.0f; // 转换为 0-360 度

        sendNamedValue("Roll",  rollDeg);
        sendNamedValue("Pitch", pitchDeg);
        sendNamedValue("Yaw",   yawDeg);

        shouldSend = true;
    }

    // =========================================================
    // 3. 执行 MAVLink 数据发送
    // =========================================================
    if (shouldSend) {
        uint16_t len = mavlink_msg_to_send_buffer(buf, &msg);
        emit dataReceived(QByteArray((char*)buf, len));
    }
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
    // 1. 提取零件并合成 SN (保持你原有的逻辑)
    int bo      = obj.value("bo").toInt();
    int ying    = obj.value("ying").toInt();
    int fli_seq = obj.value("fli_con_seq").toInt();
    int des_ver = obj.value("des_ver").toInt();
    int hw_bat  = obj.value("har_pro_bat").toInt();

    QString sn = QString("%1%2%3%4%5%6%7%8")
                    .arg(QChar(bo)).arg(QChar(ying))
                    .arg(obj.value("imp_edi").toInt())
                    .arg(obj.value("imu_ide").toInt())
                    .arg(des_ver)
                    .arg(hw_bat)
                    .arg(obj.value("har_pro_time").toInt())
                    .arg(QString("%1").arg(fli_seq, 4, 10, QChar('0')));

    // 2. 【核心优化】：将博盈信息包装成标准的 MAVLink 版本包发送
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_autopilot_version_t version;
    memset(&version, 0, sizeof(version));

    // 映射逻辑：
    // - 固件版本：使用软件序列号 fli_seq
    // - 硬件版本：使用硬件批次 hw_bat
    // - 厂商 ID：使用 'B' 'Y' 的 ASCII 组合
    version.flight_sw_version = (uint32_t)fli_seq;
    version.board_version     = (uint32_t)hw_bat;
    version.vendor_id         = (uint16_t)((bo << 8) | ying);

    // 告诉 QGC 我们的飞控支持哪些高级功能
    version.capabilities = MAV_PROTOCOL_CAPABILITY_MAVLINK2 |
                           MAV_PROTOCOL_CAPABILITY_MISSION_INT |
                           MAV_PROTOCOL_CAPABILITY_COMMAND_INT;

    // 填充 UID (QGC 需要这个来区分不同飞机)
    // 我们可以取 SN 字符串的哈希值
    version.uid = qHash(sn);

    // 打包并发送 ID #148
    mavlink_msg_autopilot_version_encode(1, 1, &msg, &version);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));

    // 3. 日志提示与状态锁定
    static QString lastSN = "";
    if (sn != lastSN) {
        lastSN = sn;
        reportToUser("飞控固件版本已对齐: " + sn, MAV_SEVERITY_INFO);
    }
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

// BoyingWorker.cc 中的映射函数实现
uint16_t BoyingWorker::_mapSdkCommandToQgc(int sdkCmd) {
    // 逻辑 B：根据你提供的表，处理非标的消息 ID 转换
    switch (sdkCmd) {
        case 11:
            // 表中定义：[MAVLINK_MSG_ID_SET_MODE, 11]
            return 176;

        case 16:
            // 表中定义：[MAVLINK_MSG_ID_NUM_REQ, 16]
            return 512;

        default:
            return (sdkCmd > 0) ? (uint16_t)sdkCmd : 0;
    }
}

void BoyingWorker::handlePacketAck(const QJsonObject& obj) {
    // 假设飞控返回 JSON: {"command": -17, "result": 0}
    int sdkCmd = obj.value("command").toInt();
    int result = obj.value("result").toInt();

    uint16_t mavlinkCmd = _mapSdkCommandToQgc(sdkCmd);
    if (mavlinkCmd == 0) return;

    // 映射执行结果
    MAV_RESULT mavRes = (result == 0) ? MAV_RESULT_ACCEPTED : MAV_RESULT_TEMPORARILY_REJECTED;

    qDebug() << ">>> [真应答收到] 指令:" << mavlinkCmd << " 结果:" << mavRes;

    // 构造标准的 COMMAND_ACK 并通过 MAVLink 频道 76 或通用频道发回给 QGC
    mavlink_message_t ackMsg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_command_ack_pack(1, 1, &ackMsg,
                                 mavlinkCmd,
                                 mavRes,
                                 255, 0,
                                 _lastQgcSystemId,   // 发回给 QGC (255)
                                 _lastQgcCommandId // 发回给对应组件
                                );

    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &ackMsg)));

    // 如果是解锁成功，顺便把本地心跳状态也更新了
    if (mavlinkCmd == MAV_CMD_COMPONENT_ARM_DISARM && mavRes == MAV_RESULT_ACCEPTED) {
        _lastMavBaseMode |= MAV_MODE_FLAG_SAFETY_ARMED;
    }
}
void BoyingWorker::_processJsonData(const QString& jsonStr) {
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) return;

    // 链路状态感知
    if (!_isFirstDataReceived) {
        reportToUser("飞控连接已恢复", 6);
        _isFirstDataReceived = true;
    }
    _dataTimeoutTimer.restart();

    QJsonArray msgArray;
    if (doc.isObject()) {
        QJsonObject root = doc.object();
        // 兼容博盈特定的包装格式
        msgArray = root.contains("msg") ? root.value("msg").toArray() : QJsonArray{root};
    } else {
        msgArray = doc.array();
    }

    for (const auto& val : msgArray) {
        QJsonObject obj = val.toObject();
        int type = obj.value("byType").toInt();
        // 执行分拣路由（保持你的 switch 结构不变）
        switch (type) {
            case 0:
            case 29: handleModePacket(obj);          break; // 状态机与心跳
            case 1:  handlePacketAck(obj);           break; // ack
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

        // --- 【核心修改点：断连瞬间的即时报警】 ---
        if (_isFirstDataReceived) {
            qDebug() << "检测到 SDK 数据停流，正在上报断连状态";

            // 1. 发送文字报警，QGC 会立刻读出“飞控连接已断开”
            // 级别建议设为 2 (MAV_SEVERITY_CRITICAL) 或 3 (MAV_SEVERITY_ERROR)
            reportToUser("警告：飞控连接已断开！", 2);

            // 2. 标记设为 false，停止后续心跳，让 QGC 的顶栏图标变灰
            _isFirstDataReceived = false;

            // 3. 【工业级补丁】重置家点状态，防止下次连上时坐标错乱
            _isHomeSet = false;
        }
        return;
    }

    // --- 只有链路正常时才执行发包逻辑 ---
    // (此处保持你原有的 mavlink_msg_heartbeat_pack 逻辑不变)
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

// 发送参数确认
void BoyingWorker::_sendMavlinkParam(const char* id, float val, uint16_t total, uint16_t index, uint8_t targetSys, uint8_t targetComp) {
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_param_value_pack(1, 1, &msg, id, val, MAV_PARAM_TYPE_REAL32, total, index);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

// 发送任务确认
void BoyingWorker::_sendMavlinkMissionCount(int count, int type, uint8_t targetSys, uint8_t targetComp) {
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    // 关键：targetSys 和 targetComp 必须是刚才请求包里发件人的 ID
    mavlink_msg_mission_count_pack(1, 1, &msg, targetSys, targetComp, count, type, 0);
    emit dataReceived(QByteArray((char*)buf, mavlink_msg_to_send_buffer(buf, &msg)));
}

// 3. 实现 ACK 发送助手
void BoyingWorker::_sendMavlinkAck(uint16_t cmdId, uint8_t result) {
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    mavlink_msg_command_ack_pack(
        1, 1, &msg,
        cmdId,
        result,
        255, 0,             // 255 代表指令已终结
        _lastQgcSystemId,
        _lastQgcCommandId
    );

    uint16_t len = mavlink_msg_to_send_buffer(buf, &msg);
    emit dataReceived(QByteArray((char*)buf, len));
}

void BoyingWorker::sendData(const QByteArray bytes)
{
#ifdef Q_OS_ANDROID
    if (!_javaSdk.isValid()) return;

    mavlink_message_t msg;
    mavlink_status_t status;

    for (int i = 0; i < bytes.length(); i++) {
        if (mavlink_parse_char(MAVLINK_COMM_0, (uint8_t)bytes[i], &msg, &status)) {

            if (msg.msgid == MAVLINK_MSG_ID_PARAM_REQUEST_LIST) {
                // 逻辑：告诉 QGC 我们只有一个名为 "SYS_ID" 的参数。
                // PX4 插件看到 index 0 == total 1 - 1，会立刻判定同步完成。
                _sendMavlinkParam("SYS_ID", 1.0f, 1, 0, msg.sysid, msg.compid);

                qDebug() << ">>> [PX4 握手] 参数同步瞬间完成";
                continue;
            }

            // --- 考题 B：获取任务统计 ---
            else if (msg.msgid == MAVLINK_MSG_ID_MISSION_REQUEST_LIST) {
                mavlink_mission_request_list_t req;
                mavlink_msg_mission_request_list_decode(&msg, &req);

                // 逻辑：直接回复当前任务数量为 0。
                // 注意：要原样回传 req.mission_type (0:任务, 1:围栏, 2:集结点)
                _sendMavlinkMissionCount(0, req.mission_type, msg.sysid, msg.compid);

                qDebug() << ">>> [PX4 握手] 任务统计已归零，类型:" << req.mission_type;
                continue;
            }

            // --- 2. 记录指令源：用于后续回传真实的异步 ACK ---
            // 关键思维：我们要记住是谁发的指令，等飞控回执到了，才能把信还给正确的人
            _lastQgcSystemId = msg.sysid;
            _lastQgcCommandId = msg.compid;

            QString jsonCmd;
            uint16_t commandId = 0;
            float p1=0, p2=0, p7=0;

            // --- 3. 按照表 76 和 11 解析指令 ---
            if (msg.msgid == MAVLINK_MSG_ID_COMMAND_LONG) { // MAVLINK_MSG_ID_COMMAND_LONG
                mavlink_command_long_t cmd; mavlink_msg_command_long_decode(&msg, &cmd);
                commandId = cmd.command; p1 = cmd.param1; p2 = cmd.param2; p7 = cmd.param7;

                // 翻译指令名
                if (commandId == MAV_CMD_NAV_TAKEOFF) {
                    jsonCmd = QString("{\"byCommand\":\"TakeOff\",\"alt\":%1}").arg(p7 > 0.5f ? p7 : 10.0f);
                }else if (commandId == MAV_CMD_DO_SET_MODE) {
                    int customModeInt = static_cast<int>(p2);

                    jsonCmd = QString(
                        "{\"byCommand\":\"SetFlightMode\",\"baseMode\":1,\"customMode\":%2}"
                    ).arg(customModeInt);
                }else if (commandId == MAV_CMD_COMPONENT_ARM_DISARM) {
                    jsonCmd = QString("{\"byCommand\":\"%1\"}").arg(p1 > 0.5f ? "DisArm" : "Arm");
                } else if (commandId == MAV_CMD_NAV_LAND) {
                    jsonCmd = "{\"byCommand\":\"Land\"}";
                } else if (commandId == MAV_CMD_NAV_RETURN_TO_LAUNCH) {
                    jsonCmd = "{\"byCommand\":\"ReturnBack\"}";
                }
            }
            // else if (msg.msgid == MAV_CMD_DO_SET_MODE) { // MAVLINK_MSG_ID_SET_MODE
            //     mavlink_set_mode_t mode; mavlink_msg_set_mode_decode(&msg, &mode);
            //     commandId = MAVLINK_MSG_ID_SET_MODE; // 映射为 MAV_CMD_DO_SET_MODE
            // }
            // --- 4. 执行 JNI 下发 ---
            if (!jsonCmd.isEmpty()) {
                qDebug() << "TX JSON:" << jsonCmd;
                QJniObject jStr = QJniObject::fromString(jsonCmd);
                jint sdkResult = QJniObject::callStaticMethod<jint>("org/qjkj/gcs/QGCConnectionManager",
                                                                    "sendDataWithResult", "(Ljava/lang/String;)I", jStr.object<jstring>());

                // 只有 JNI 级别报错（比如链路完全断了）才立刻回失败 ACK
                if (sdkResult != 0) {
                    _sendMavlinkAck(commandId, MAV_RESULT_FAILED);
                }
                // 如果 sdkResult == 0，此处保持沉默，等待 handlePacketAck 函数触发
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
