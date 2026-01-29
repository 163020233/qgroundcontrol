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


//
// static const MockParam s_mockParams[] = {
//     {"SYS_AUTOSTART",   4001.0f, 6},
//     {"MAV_TYPE",        2.0f,    6},
//     {"MAV_PROTO_VER",   200.0f,  6},
//     {"COM_RC_IN_MODE",  1.0f,    6},
//     {"NAV_RCL_ACT",     0.0f,    6},
//     {"COM_ARM_CHK_ES",  0.0f,    6},
//     {"CBRK_SUPPLY_CHK", 894281.0f, 6},
//     {"CBRK_USB_CHK",    197848.0f, 6},
//     {"COM_ARM_WO_GPS",  1.0f,    6},
//     {"CAL_ACC0_ID",     1234.0f, 6},
//     {"CAL_GYRO0_ID",    1234.0f, 6},
//     {"CAL_MAG0_ID",     1234.0f, 6},
//     {"BAT_N_CELLS",     12.0f,    6},
//     {"MIS_TAKEOFF_ALT", 10.0f,   9},
//     {"RTL_RETURN_ALT",  30.0f,   9}
// };
// static const int s_paramCount = sizeof(s_mockParams)/sizeof(MockParam);

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

// void BoyingWorker::onJavaDataReceived(const QByteArray& rawData)
// {
// #ifdef Q_OS_ANDROID
//     if (rawData.isEmpty()) return;
//     // 打印长度，如果是少量数据可以打印 toHex()
//     // qDebug() << "[RX RAW] Len:" << rawData.size() << "Bytes:" << rawData.toHex();
//
//     QJniEnvironment env;
//     jbyteArray jData = env->NewByteArray(rawData.size());
//     env->SetByteArrayRegion(jData, 0, rawData.size(), reinterpret_cast<const  jbyte*>(rawData.data()));
//
//     QJniObject jJsonStr = _javaSdk.callObjectMethod(
//         "GetJsonByByteJava",
//         "([BI)Ljava/lang/String;",
//         jData,
//         (jint)rawData.size()
//     );
//     env->DeleteLocalRef(jData);
//
//     if (jJsonStr.isValid()) {
//         QString jsonString = jJsonStr.toString();
//
//         if (!jsonString.isEmpty()) {
//             // =========================================================
//             //  打印点 2: 确认 SDK 解析成功 (业务数据检查)
//             // =========================================================
//             // qDebug() << "[RX JSON]" << jsonString;
//
//             _processJsonData(jsonString);
//         } else {
//             qWarning() << "[RX Error] SDK returned Empty String (Parse Failed?)";
//         }
//     } else {
//         qCritical() << "RX Error] JNI Call GetJsonByByteJava returned NULL";
//     }
// #endif
// }

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

void BoyingWorker::_processJsonData(const QString& jsonStr)
{

    _isFirstDataReceived = true; // 标志位：收到过数据了
    _dataTimeoutTimer.restart(); // 刷新计时

    // ---------- 1. 解析 JSON（带错误检查） ----------
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) {
        qWarning() << "JSON parse error:" << err.errorString() << jsonStr;
        return;
    }

    qDebug() << "RX JSON:" << jsonStr;

    // ---------- 2. 统一成 msgArray（兼容 Object / Array） ----------
    QJsonArray msgArray;

    if (doc.isObject()) {
        QJsonObject root = doc.object();

        // {"msg":[...]}
        if (root.contains("msg") && root.value("msg").isArray()) {
            msgArray = root.value("msg").toArray();
        }
        // {"byType":...}
        else {
            msgArray.append(root);
        }
    }
    // [{"byType":...}, {...}]
    else if (doc.isArray()) {
        msgArray = doc.array();
    }
    else {
        return;
    }

    for (const auto& val : msgArray) {
        QJsonObject obj = val.toObject();
        int type = obj.value("byType").toInt();

        mavlink_message_t msg;
        uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
        bool send = false;



        // 在 BoyingWorker.cc 的 _processJsonData 中添加处理
        if (type == 29 || type == 0) { // 兼容你提到的 Type 29 模式包
            int customMode = obj.value("custom_mode").toInt(); // 2, 3, 5, 6
            int baseMode   = obj.value("base_mode").toInt();   // 1
            int sysStatus  = obj.value("system_status").toInt(); // 假设有这个字段

            // --- 1. 文本提示转换逻辑 ---

            // --- 1. 模式映射逻辑 (仅更新变量) ---
            uint32_t arduMode = 0;
            switch (customMode) {
                case 0:  arduMode = 0;  break;
                case 2:  arduMode = 2;  break;
                case 5:  arduMode = 5;  break;
                case 6:  arduMode = 6;  break;
                case 3:  arduMode = 3;  break;
                case 17: arduMode = 17; break; // 映射为 ArduPilot 的 Brake
                default: arduMode = 5;  break;
            }
            _lastArduMode = arduMode; // 更新缓存

            // --- 2. 解锁状态映射 (仅更新变量) ---
            uint8_t mavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
            if (baseMode & 128) mavBaseMode |= MAV_MODE_FLAG_SAFETY_ARMED;
            _lastMavBaseMode = mavBaseMode; // 更新缓存

            // --- 3. 系统状态映射 (仅更新变量) ---
            if (sysStatus == 4)      _lastMavState = MAV_STATE_ACTIVE;
            else if (sysStatus == 5) _lastMavState = MAV_STATE_CRITICAL;
            else                     _lastMavState = MAV_STATE_STANDBY;

            //         // --- 2. 如果模式发生改变，主动发送 STATUSTEXT 给 QGC ---
            // if (_lastCustomMode != customMode) {
            //     _lastCustomMode = customMode;
            //
            //     mavlink_message_t txtMsg;
            //     uint8_t txtBuf[MAVLINK_MAX_PACKET_LEN];
            //     QByteArray utf8Text = modeName.toUtf8();
            //
            //     // 发送给 QGC 的消息等级设为 INFO (6)
            //     mavlink_msg_statustext_pack(1, 1, &txtMsg,
            //                                 MAV_SEVERITY_INFO,
            //                                 utf8Text.data(),
            //                                 0, 0);
            //
            //     uint16_t txtLen = mavlink_msg_to_send_buffer(txtBuf, &txtMsg);
            //     emit dataReceived(QByteArray((char*)txtBuf, txtLen));
            // }

            //         // --- 3. 发送心跳包 (使用原始 ID，身份设为 GENERIC) ---
            // mavlink_message_t hbMsg;
            // uint8_t hbBuf[MAVLINK_MAX_PACKET_LEN];
            //
            // // 如果 baseMode 为 1 且博盈逻辑中代表解锁，则添加 ARMED 标志
            // uint8_t mavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
            // // 假设你的解锁状态在 Type 0 或其他地方获取，这里暂时按 baseMode 透传
            // if (baseMode & 128) mavBaseMode |= MAV_MODE_FLAG_SAFETY_ARMED;
            //
            // mavlink_msg_heartbeat_pack(1, 1, &hbMsg,
            //                            MAV_TYPE_QUADROTOR,
            //                            MAV_AUTOPILOT_ARDUPILOTMEGA, // <--- 声明为通用飞控，不借用 PX4 字典
            //                            mavBaseMode,
            //                            (uint32_t)customMode,  // <--- 直接发 2, 3, 5, 6
            //                            MAV_STATE_STANDBY);
            //
            // uint16_t hbLen = mavlink_msg_to_send_buffer(hbBuf, &hbMsg);
            // emit dataReceived(QByteArray((char*)hbBuf, hbLen));
        }

        // =========================================================
        // 2. 飞控版本信息 (Type 2)
        if (type == 2) {
            harvestParam("SW_VER", (float)obj.value("fli_con_seq").toInt());
            harvestParam("HW_VER", (float)obj.value("har_pro_bat").toInt());
            harvestParam("VENDOR_ID", (float)obj.value("bo").toInt());
        }

// =========================================================
        // Type 3: GPS 数据 (根据文档精确解析)
        // =========================================================
        else if (type == 3) {
            int fixTypeRaw = obj.value("fixType").toInt();
            int satCount = obj.value("count").toInt();
            int lat = obj.value("lat").toInt(); // WGS84 1E7
            int lon = obj.value("lon").toInt(); // WGS84 1E7
            int alt = obj.value("alt").toInt(); // mm

            // 文档: eph/epv 单位 m*100 (即厘米 cm)
            int ephCm = obj.value("eph").toInt();
            int epvCm = obj.value("epv").toInt();
            int vel = obj.value("vel").toInt(); // cm/s
            int cog = obj.value("cog").toInt(); // c
            // 1. 映射 Fix Type (关键!)
            // SDK: 0:NO GPS, 1:NO FIX, 2:2D, 3:3D, 4:3D, 5:RTK, 6:FLOAT
            uint8_t mavFix = GPS_FIX_TYPE_NO_GPS;
            switch (fixTypeRaw) {
                case 1: mavFix = GPS_FIX_TYPE_NO_FIX; break;
                case 2: mavFix = GPS_FIX_TYPE_2D_FIX; break;
                case 3: mavFix = GPS_FIX_TYPE_3D_FIX; break;
                case 4: mavFix = GPS_FIX_TYPE_3D_FIX; break; // 4也是3D
                case 5: mavFix = GPS_FIX_TYPE_RTK_FIXED; break; // SDK 5 = RTK Fixed
                case 6: mavFix = GPS_FIX_TYPE_RTK_FLOAT; break; // SDK 6 = FLOAT
                default: mavFix = GPS_FIX_TYPE_NO_GPS; break;
            }

            // 2. 单位转换 (cm -> mm) 用于 MAVLink v2 的 h_acc/v_acc
            // 处理无效值 (通常 9999 代表无效)
            uint32_t h_acc_mm = (ephCm > 9000 || ephCm <= 0) ? 0 : (uint32_t)(ephCm * 10);
            uint32_t v_acc_mm = (epvCm > 9000 || epvCm <= 0) ? 0 : (uint32_t)(epvCm * 10);

            // 兼容旧版 eph (cm)
            uint16_t legacy_eph = (uint16_t)(h_acc_mm / 10);
            uint16_t legacy_epv = (uint16_t)(v_acc_mm / 10);

            // 3. 打包发送
            mavlink_msg_gps_raw_int_pack(1, 1, &msg,
                QDateTime::currentMSecsSinceEpoch() * 1000, // time_usec
                mavFix,
                lat,
                lon,
                alt,
                legacy_eph,
                legacy_epv,
                (uint16_t)vel,
                (uint16_t)cog,
                (uint8_t)satCount,
                alt,        // alt_ellipsoid (未知时填海拔)
                h_acc_mm,   // h_acc (mm)
                v_acc_mm,   // v_acc (mm)
                0,          // vel_acc
                0,          // hdg_acc
                0           // yaw
            );
            send = true;
        }

        // =========================================================
        // Type 4: RTK 数据 (作为副 GPS 发送，可选)
        // =========================================================
        else if (type == 4) {
            // 如果你想在 QGC 看到 RTK 状态，可以把它发为 GPS2
            // 这里逻辑和 Type 3 几乎一样，只是 Message ID 不同
            // ... (如果不需要可以不写，通常 Type 3 已经包含了融合后的 RTK 状态)
        }

        // =========================================================
        // Type 5: 系统状态 (电压与传感器)
        // =========================================================
        else if (type == 5) {
            int voltageCv = obj.value("voltage_battery").toInt();
            float vV = (float)voltageCv / 100.0f;
            uint16_t voltageMv = (uint16_t)(voltageCv * 10);

            // 1. 获取原始电量（可能是 255）
            int remain = obj.value("battery_remaining").toInt();
            float rawPercent = 0.0f;

            if (remain >= 0 && remain <= 100) {
                rawPercent = (float)remain;
            } else {
                // 如果是 255，根据 12S 电压计算
                float cellV = vV / 12.0f;
                rawPercent = (cellV - 3.6f) / (4.2f - 3.6f) * 100.0f;
            }
            rawPercent = qBound(0.0f, rawPercent, 100.0f);

            // 2. 【核心优化：平滑滤波】
            if (_smoothBatteryPercent < 0) {
                // 第一次运行，直接赋值
                _smoothBatteryPercent = rawPercent;
            } else {
                // 工业级平滑公式：新值仅贡献 5%，防止数字跳动
                _smoothBatteryPercent = (_smoothBatteryPercent * 0.95f) + (rawPercent * 0.05f);
            }

            // 最终显示用的整数（四舍五入）
            int8_t displayRemain = (int8_t)qRound(_smoothBatteryPercent);

            // 3. 发送 MAVLink 消息
            // 使用 displayRemain 替代之前的 remain
            mavlink_message_t batMsg;
            uint8_t batBuffer[MAVLINK_MAX_PACKET_LEN];

            // 发送 SYS_STATUS
            mavlink_msg_sys_status_pack(1, 1, &batMsg,
                obj.value("onboard_control_sensors_present").toVariant().toUInt(),
                obj.value("onboard_control_sensors_enabled").toVariant().toUInt(),
                obj.value("onboard_control_sensors_health").toVariant().toUInt(),
                (uint16_t)obj.value("load").toInt(),
                voltageMv, -1, displayRemain, 0, 0, 0, 0, 0, 0,0,0,0);
            emit dataReceived(QByteArray((char*)batBuffer, mavlink_msg_to_send_buffer(batBuffer, &batMsg)));

            // 发送 BATTERY_STATUS
            uint16_t vArr[10] = {voltageMv, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            mavlink_msg_battery_status_pack(1, 1, &batMsg, 0, 1, 3, 25, vArr, -1, -1, -1, displayRemain, 1,0,0,0,0);
            emit dataReceived(QByteArray((char*)batBuffer, mavlink_msg_to_send_buffer(batBuffer, &batMsg)));
        }

        // =========================================================
        // 6. 磁罗盘/IMU 数据 (Type 6) -> SCALED_IMU
        // =========================================================
        else if (type == 6) {
            int xacc = obj.value("xacc").toInt();
            int yacc = obj.value("yacc").toInt();
            int zacc = obj.value("zacc").toInt();
            int xgyro = obj.value("xgyro").toInt();
            int ygyro = obj.value("ygyro").toInt();
            int zgyro = obj.value("zgyro").toInt();
            int xmag = obj.value("xmag").toInt();
            int ymag = obj.value("ymag").toInt();
            int zmag = obj.value("zmag").toInt();
            int boot_ms = obj.value("time_boot_ms").toInt();

            mavlink_msg_scaled_imu_pack(1, 1, &msg,
                boot_ms,
                (int16_t)xacc, (int16_t)yacc, (int16_t)zacc,
                (int16_t)xgyro, (int16_t)ygyro, (int16_t)zgyro,
                (int16_t)xmag, (int16_t)ymag, (int16_t)zmag,
                0 // temperature (unknown)
            );
            send = true;
        }

        // =========================================================
        // Type 7: 震动数据 (VIBRATION) - 修正版
        // 日志: {"vibration_x":0.003933, "vibration_y":0.003890, "vibrationZ":0.003578, "clipping_0":0...}
        // =========================================================
        else if (type == 7) {
            // 1. 解析三轴震动 (直接取值，没值默认为0)
            float vibX = (float)obj.value("vibration_x").toDouble();
            float vibY = (float)obj.value("vibration_y").toDouble();
            float vibZ = (float)obj.value("vibrationZ").toDouble(); // 注意厂家拼写是大写Z

            // 2. 解析 Clipping (震动削顶计数，用于判断震动是否过大)
            uint32_t clip0 = (uint32_t)obj.value("clipping_0").toInt();
            uint32_t clip1 = (uint32_t)obj.value("clipping_1").toInt();
            uint32_t clip2 = (uint32_t)obj.value("clipping_2").toInt();

            // 3. 解析时间戳
            uint64_t time_usec = (uint64_t)obj.value("time_usec").toDouble();
            if (time_usec == 0) {
                time_usec = QDateTime::currentMSecsSinceEpoch() * 1000;
            }

            mavlink_msg_vibration_pack(1, 1, &msg,
                time_usec,
                vibX,
                vibY,
                vibZ,
                clip0,
                clip1,
                clip2
            );
            send = true;
        }

        // =========================================================
        // Type 8: HUD 数据 (VFR_HUD)
        // 协议: airspeed(m/s), groundspeed(m/s), alt(m), climb(m/s), throttle(%)
        // =========================================================
        else if (type == 8) {
            float airSpeed = (float)obj.value("airspeed").toDouble();
            float groundSpeed = (float)obj.value("groundspeed").toDouble();
            float alt = (float)obj.value("alt").toDouble();
            float climb = (float)obj.value("climb").toDouble();
            int throttle = obj.value("throttle").toInt();

            // heading (航向) 协议里没写，但 VFR_HUD 需要。
            // 我们可以给 0，或者看 JSON 里有没有隐藏的 heading 字段
            int16_t heading = 0;
            if (obj.contains("heading")) heading = (int16_t)obj.value("heading").toInt();

            mavlink_msg_vfr_hud_pack(1, 1, &msg,
                airSpeed,
                groundSpeed,
                heading,
                throttle,
                alt,
                climb);
            send = true;
        }
        // =========================================================
        // Type 9: 姿态数据 (ATTITUDE)
        // 协议: roll, pitch, yaw (rad), speeds (rad/s)
        // =========================================================
        else if (type == 9) {
            float roll = (float)obj.value("roll").toDouble();
            float pitch = (float)obj.value("pitch").toDouble();
            float yaw = (float)obj.value("yaw").toDouble();

            float rollspeed = (float)obj.value("rollspeed").toDouble();
            float pitchspeed = (float)obj.value("pitchspeed").toDouble();
            float yawspeed = (float)obj.value("yawspeed").toDouble();

            mavlink_msg_attitude_pack(1, 1, &msg,
                QDateTime::currentMSecsSinceEpoch(),
                roll, pitch, yaw,
                rollspeed, pitchspeed, yawspeed);
            send = true;
        }

        // =========================================================
        // Type 12: 定位数据 (GLOBAL_POSITION_INT)
        // 协议: lat/lon(*1E7), alt(mm), vx/vy/vz(m/s*100 -> cm/s)
        // =========================================================
        else if (type == 12) {
            int32_t lat = obj.value("lat").toInt();
            int32_t lon = obj.value("lon").toInt();
            int32_t alt = obj.value("alt").toInt(); // 海拔 (mm)

            // 协议未提及 relative_alt (相对高度)，但之前的日志里有。
            // 如果 JSON 里没有 relative_alt，QGC 的高度会显示海拔（可能很大）。
            // 建议：如果有 relative_alt 就用，没有就用 alt。
            int32_t relative_alt = alt;
            if (obj.contains("relative_alt")) {
                relative_alt = obj.value("relative_alt").toInt();
            }

            // 速度: 协议说是 m/s*100 = cm/s
            // MAVLink vx/vy/vz 也是 cm/s，所以直接透传，不需要转换
            int16_t vx = (int16_t)obj.value("vx").toInt();
            int16_t vy = (int16_t)obj.value("vy").toInt(); // 注意: 你的描述里 vx 写了两次，这里应该是 vy
            int16_t vz = (int16_t)obj.value("vz").toInt();

            // 航向: 协议未提及，但之前的日志有 hdg (cdeg)
            uint16_t hdg = 0;
            if (obj.contains("hdg")) hdg = (uint16_t)obj.value("hdg").toInt();

            mavlink_msg_global_position_int_pack(1, 1, &msg,
                QDateTime::currentMSecsSinceEpoch(),
                lat, lon,
                alt,
                relative_alt,
                vx, vy, vz,
                hdg);
            send = true;
        }

        // =========================================================
        // Type 13: 雷达数据 (DISTANCE_SENSOR)
        // 协议: distance (float, 单位米)
        // =========================================================
        else if (type == 13) {
            float distM = (float)obj.value("distance").toDouble();

            // MAVLink 单位是 cm，所以要 * 100
            uint16_t distCm = (uint16_t)(distM * 100);

            // 只有有效距离才发送 (比如大于0)
            if (distCm > 0) {
                mavlink_msg_distance_sensor_pack(1, 1, &msg,
                    0, // time_boot_ms
                    0, // min_distance
                    10000, // max_dis需要调整
                    distCm,
                    MAV_DISTANCE_SENSOR_RADAR, // 传感器类型：雷达
                    0, // id
                    MAV_SENSOR_ROTATION_PITCH_270, // 方向：向下 (270度)
                    0, 0, 0, 0,0);
                send = true;
            }
        }

        // =========================================================
        // Type 14: 植保作业数据 (映射为自定义命名变量)
        // =========================================================
        // --- 提取作业载荷数据 (Type 14) ---
        else if (type == 14) {
            // 将作业参数也同步到参数列表，方便在 QGC 参数表查看
            harvestParam("BY_WORK_TIME", (float)obj.value("command1").toInt());
            harvestParam("BY_FLOW_RATE", (float)obj.value("command4").toDouble());
            harvestParam("BY_TOTAL_VOL", (float)obj.value("command5").toDouble());
        }

        // =========================================================
        // Type 20: 文本信息 (STATUSTEXT)
        // 协议: severity(int), text(byte[])
        // =========================================================
        else if (type == 20) {
            int severity = obj.value("severity").toInt();

            // 这里的 severity 映射可能的，直接用。

            // 解析 text 数组
            // 之前的日志显示 text 是一个 int 数组: [92, 117, 53, ...]
            QJsonArray textArr = obj.value("text").toArray();
            QByteArray rawBytes;
            for(const auto& item : textArr) {
                rawBytes.append((char)item.toInt());
            }

            // 如果是 Unicode 转义符 (如 \u5929)，需要解码；如果是 UTF8，直接用
            // 之前的 unescapeUnicode 函数可以保留，以防万一
            QString decodedStr = unescapeUnicode(QString::fromUtf8(rawBytes));

            // 截断到 50 字节
            char textBuf[50] = {0};
            QByteArray finalBytes = decodedStr.toUtf8();
            int len = qMin((int)finalBytes.size(), 49);
            memcpy(textBuf, finalBytes.constData(), len);

            mavlink_msg_statustext_pack(1, 1, &msg,
                (uint8_t)severity,
                textBuf,
                0, 0);
            send = true;
        }

        // =========================================================
        // 12. 舵机/电机输出 (Type 21) -> SERVO_OUTPUT_RAW
        // =========================================================
        else if (type == 21) {
            mavlink_msg_servo_output_raw_pack(1, 1, &msg,
                QDateTime::currentMSecsSinceEpoch() * 1000,
                0, // port
                (uint16_t)obj.value("servo1_raw").toInt(),
                (uint16_t)obj.value("servo2_raw").toInt(),
                (uint16_t)obj.value("servo3_raw").toInt(),
                (uint16_t)obj.value("servo4_raw").toInt(),
                (uint16_t)obj.value("servo5_raw").toInt(),
                (uint16_t)obj.value("servo6_raw").toInt(),
                (uint16_t)obj.value("servo7_raw").toInt(),
                (uint16_t)obj.value("servo8_raw").toInt(),
                0, 0, 0, 0, 0, 0, 0, 0 // 9-16 保留0
            );
            send = true;
        }

        // =========================================================
        // 13. 遥控器通道输入 (Type 25 或 Type 22) -> RC_CHANNELS
        // =========================================================
        else if (type == 25 || type == 22) {
            int rssi = obj.value("rssi").toInt();

            mavlink_rc_channels_t rc;
            memset(&rc, 0, sizeof(rc));

            rc.time_boot_ms = QDateTime::currentMSecsSinceEpoch();
            rc.chancount = (type == 22) ? 18 : 8;
            rc.rssi = (uint8_t)rssi;

            // 宏：简化取值
            auto getChan = [&](int i) -> uint16_t {
                return (uint16_t)obj.value(QString("chan%1_raw").arg(i)).toInt();
            };

            rc.chan1_raw = getChan(1);
            rc.chan2_raw = getChan(2);
            rc.chan3_raw = getChan(3);
            rc.chan4_raw = getChan(4);
            rc.chan5_raw = getChan(5);
            rc.chan6_raw = getChan(6);
            rc.chan7_raw = getChan(7);
            rc.chan8_raw = getChan(8);

            if (type == 22) {
                rc.chan9_raw  = getChan(9);
                rc.chan10_raw = getChan(10);
                rc.chan11_raw = getChan(11);
                rc.chan12_raw = getChan(12);
                rc.chan13_raw = getChan(13);
                rc.chan14_raw = getChan(14);
                rc.chan15_raw = getChan(15);
                rc.chan16_raw = getChan(16);
                rc.chan17_raw = getChan(17);
                rc.chan18_raw = getChan(18);
            } else {
                rc.chan9_raw = UINT16_MAX;
                // ... 10-18 默认为0或MAX
            }

            mavlink_msg_rc_channels_encode(1, 1, &msg, &rc);
            send = true;
        }

        // =========================================================
        // 14. 系统时间 (Type 23) -> SYSTEM_TIME
        // =========================================================
        else if (type == 23) {
            uint32_t boot_ms = (uint32_t)obj.value("time_boot_ms").toInt();
            uint64_t unix_us = (uint64_t)obj.value("time_unix_usec").toDouble();

            mavlink_msg_system_time_pack(1, 1, &msg, unix_us, boot_ms);
            send = true;
        }

        // =========================================================
        // Type 26: 测距传感器/雷达 (DISTANCE_SENSOR)
        // 日志: {"diatance":4000, "status":0, "type":0 ...}
        // =========================================================
        // --- 提取测距雷达状态 (Type 26) ---
        else if (type == 26) {
            harvestParam("SENS_DIST_GND", (float)obj.value("diatance").toInt());
        }

        if (send) {
            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));
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
    qDebug() << "[BoyingLink] QGC trying to send bytes, len:" << bytes.length();

    if (_is_connected) {
        emit _workerSend(bytes);
    } else {
        qWarning() << "[BoyingLink] Dropped bytes because link is disconnected";
    }
}
void BoyingLink::_onWorkerData(QByteArray data) { emit bytesReceived(this, data); }
