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
    // 对应 Java: public static native void nativeOnJsonReceived(String jsonStr);
    JNIEXPORT void JNICALL
    Java_org_qjkj_gcs_QGCConnectionManager_nativeOnJsonReceived(JNIEnv *env, jclass, jstring jsonStr) {
        if (!s_worker) return;

        // 1. 将 Java String 转换为 C++ QString
        const char *nativeString = env->GetStringUTFChars(jsonStr, nullptr);
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

// extern "C" {
//     JNIEXPORT void JNICALL
    // Java_org_qjkj_gcs_QGCConnectionManager_nativeOnDataReceived(JNIEnv *env, jclass, jbyteArray data, jint len) {
    //
    //     QMutexLocker locker(&s_workerMutex);
    //
    //     // ★★★ QPointer 检查：如果对象已销毁，s_worker 会自动变为 null，绝对安全 ★★★
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

    // 3. 【第二阶段加锁】：更新初始化标记
    // QMutexLocker locker(&s_workerMutex);
    // {
    //
    //     // s_isSdkInitialized = true;
    // }

    qDebug() << "Hybrid Link Initialized!";
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
//             // ★★★ 打印点 2: 确认 SDK 解析成功 (业务数据检查) ★★★
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

void BoyingWorker::_processJsonData(const QString& jsonStr)
{
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

        if (type == 0) {
            int customMode = obj.value("custom_mode").toInt();
            int baseMode = obj.value("base_mode").toInt();
            int sysStatus = obj.value("system_status").toInt();

            // --- A. 模式映射 ---
            uint32_t px4Mode = 65536; // 默认 Manual
            switch (customMode) {
                case 0:  px4Mode = 65536;    break; // Manual
                case 2:  px4Mode = 131072;   break; // Altitude
                case 3:  px4Mode = 262144;   break; // 自主作业 -> 映射为 Position (定点) 比较安全
                case 5:  px4Mode = 262144;   break; // Position
                case 6:  px4Mode = 84148224; break; // RTL
                case 9:  px4Mode = 50593792; break; // Land
                case 17: px4Mode = 83886080; break; // Loiter
                default: px4Mode = 65536;    break;
            }

            // --- B. 解锁状态映射 ---
            bool isArmed = (baseMode & 128) == 128;
            uint8_t mavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
            if (isArmed) mavBaseMode |= MAV_MODE_FLAG_SAFETY_ARMED;

            // --- C. 系统状态映射 (核心修改) ---
            // 厂商定义: 3=未准备, 4=已起飞, 5=有故障
            uint8_t mavState = MAV_STATE_STANDBY; // 默认待机

            if (sysStatus == 5) {
                mavState = MAV_STATE_CRITICAL;      // 5 -> 严重故障 (红)
            }
            else if (sysStatus == 4) {
                mavState = MAV_STATE_ACTIVE;        // 4 -> 飞行中 (绿)
            }
            else if (sysStatus == 3) {
                // ★★★ 3 -> 映射为 CALIBRATING (校准中/初始化中) ★★★
                // 这样 QGC 会认为飞机"未就绪"，符合厂商定义的"未准备"
                mavState = MAV_STATE_CALIBRATING;
            }
            else {
                mavState = MAV_STATE_STANDBY;       // 其他情况视为待机
            }

            // --- D. 发送心跳 ---
            mavlink_msg_heartbeat_pack(1, 1, &msg,
                MAV_TYPE_QUADROTOR, MAV_AUTOPILOT_PX4,
                mavBaseMode, px4Mode, mavState);

            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));
            // 发送 ESTIMATOR_STATUS (解决 EKF 报错)
            {
                mavlink_estimator_status_t est;
                memset(&est, 0, sizeof(est));
                est.flags = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4); // 全好
                est.vel_ratio = 1.0f;
                est.pos_horiz_ratio = 1.0f;
                mavlink_message_t estMsg;
                mavlink_msg_estimator_status_encode(1, 1, &estMsg, &est);
                len = mavlink_msg_to_send_buffer(buffer, &estMsg);
                emit dataReceived(QByteArray((char*)buffer, len));
            }

            // 注意：Type 0 里不再伪造 SYS_STATUS 和 GPS，由下面的 Type 5 和 Type 12 负责
        }

        // =========================================================
        // 2. 飞控版本信息 (Type 2)
        // =========================================================
        else if (type == 2) {
             uint32_t sw_ver = (uint32_t)obj.value("fli_con_seq").toInt();
             uint32_t hw_ver = (uint32_t)obj.value("har_pro_bat").toInt();
             uint16_t vendor_id = ((uint16_t)obj.value("bo").toInt() << 8) | (uint16_t)obj.value("ying").toInt();

             mavlink_autopilot_version_t apVer;
             memset(&apVer, 0, sizeof(apVer));
             apVer.capabilities = MAV_PROTOCOL_CAPABILITY_MISSION_INT |
                                  MAV_PROTOCOL_CAPABILITY_COMMAND_INT |
                                  MAV_PROTOCOL_CAPABILITY_MAVLINK2;
             apVer.flight_sw_version = sw_ver;
             apVer.board_version = hw_ver;
             apVer.vendor_id = vendor_id;

             mavlink_msg_autopilot_version_encode(1, 1, &msg, &apVer);
             send = true;
        }

        // =========================================================
        // 3. GPS 基础数据 (Type 3)
        // =========================================================
        else if (type == 3) {
            int fixType = obj.value("fixType").toInt();
            int sat = obj.value("count").toInt();
            int eph = obj.value("eph").toInt();
            int epv = obj.value("epv").toInt();

            uint8_t mavFix = 0;
            switch(fixType) {
                case 2: mavFix = 2; break; // 2D
                case 3: mavFix = 3; break; // 3D
                case 4: mavFix = 3; break; // 3D
                case 5: mavFix = 6; break; // RTK FIXED
                case 6: mavFix = 5; break; // RTK FLOAT
                default: mavFix = 0; break;
            }

            // 只有有效才发送，避免覆盖 Type 12
            if (mavFix >= 2) {
                mavlink_gps_raw_int_t gps;
                memset(&gps, 0, sizeof(gps));
                gps.fix_type = mavFix;
                gps.lat = obj.value("lat").toInt();
                gps.lon = obj.value("lon").toInt();
                gps.alt = obj.value("alt").toInt();
                gps.eph = (eph == 0) ? 0xFFFF : (uint16_t)eph;
                gps.epv = (epv == 0) ? 0xFFFF : (uint16_t)epv;
                gps.vel = 0xFFFF;
                gps.cog = 0xFFFF;
                gps.satellites_visible = (uint8_t)sat;

                mavlink_msg_gps_raw_int_encode(1, 1, &msg, &gps);
                send = true;
            }
        }

        // =========================================================
        // 4. RTK GPS 数据 (Type 4)
        // =========================================================
        else if (type == 4) {
             // ... (如果你需要处理 GPS2，可以在这里添加 mavlink_msg_gps_2_raw_encode) ...
        }

        // =========================================================
        // 5. 系统状态 (Type 5)
        // =========================================================
        else if (type == 5) {
            int voltageRaw = obj.value("voltage_battery").toInt();
            int voltageMv = voltageRaw * 10;
            if (voltageMv < 1000) voltageMv = 22200;

            int remain = obj.value("battery_remaining").toInt();
            if (remain < 0) remain = 50;
            int load = obj.value("load").toInt();

            qint64 healthBits = (qint64)obj.value("onboard_control_sensors_health").toDouble();
            uint32_t mavSensors = 0;
            if ((healthBits >> 0) & 1) mavSensors |= MAV_SYS_STATUS_SENSOR_3D_GYRO;
            if ((healthBits >> 1) & 1) mavSensors |= MAV_SYS_STATUS_SENSOR_3D_ACCEL;
            if ((healthBits >> 2) & 1) mavSensors |= MAV_SYS_STATUS_SENSOR_3D_MAG;
            if ((healthBits >> 5) & 1) mavSensors |= MAV_SYS_STATUS_SENSOR_GPS;

            mavSensors |= MAV_SYS_STATUS_SENSOR_ABSOLUTE_PRESSURE;
            mavSensors |= MAV_SYS_STATUS_AHRS;
            mavSensors |= MAV_SYS_STATUS_SENSOR_BATTERY;

            mavlink_sys_status_t sys;
            memset(&sys, 0, sizeof(sys));
            sys.onboard_control_sensors_present = mavSensors;
            sys.onboard_control_sensors_enabled = mavSensors;
            sys.onboard_control_sensors_health  = mavSensors;
            sys.voltage_battery = (uint16_t)voltageMv;
            sys.current_battery = -1;
            sys.battery_remaining = (int8_t)remain;
            sys.load = (uint16_t)(load * 10);

            mavlink_msg_sys_status_encode(1, 1, &msg, &sys);
            send = true;
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
        // 7. 震动数据 (Type 7) -> VIBRATION
        // =========================================================
        else if (type == 7) {
            float vibX = (float)obj.value("vibration_x").toDouble();
            float vibY = (float)obj.value("vibration_y").toDouble();
            float vibZ = (float)obj.value("vibrationZ").toDouble();

            mavlink_msg_vibration_pack(1, 1, &msg,
                0, // time_usec
                vibX, vibY, vibZ,
                0, 0, 0 // clipping
            );
            send = true;
        }

        // =========================================================
        // 8. HUD 数据 (Type 8)
        // =========================================================
        else if (type == 8) {
            mavlink_msg_vfr_hud_pack(1, 1, &msg,
                (float)obj.value("airspeed").toDouble(),
                (float)obj.value("groundspeed").toDouble(),
                0,
                (uint16_t)obj.value("throttle").toInt(),
                (float)obj.value("alt").toDouble(),
                (float)obj.value("climb").toDouble());
            send = true;
        }

        // =========================================================
        // 9. 姿态 (Type 9)
        // =========================================================
        else if (type == 9) {
            float roll = (float)obj.value("roll").toDouble();
            float pitch = (float)obj.value("pitch").toDouble();
            float yaw = (float)obj.value("yaw").toDouble();

            mavlink_msg_attitude_pack(1, 1, &msg, 0, roll, pitch, yaw, 0, 0, 0);
            send = true;
        }

        // =========================================================
        // 10. 定位数据 (Type 12)
        // =========================================================
        else if (type == 12) {
            int32_t lat = obj.value("lat").toInt();
            int32_t lon = obj.value("lon").toInt();
            int32_t alt = obj.value("alt").toInt();
            int16_t vx = (int16_t)obj.value("vx").toInt();
            int16_t vy = (int16_t)obj.value("vy").toInt();
            int16_t vz = (int16_t)obj.value("vz").toInt();
            uint16_t hdg = (uint16_t)obj.value("hdg").toInt();

            mavlink_msg_global_position_int_pack(1, 1, &msg,
                QDateTime::currentMSecsSinceEpoch(),
                lat, lon, alt, alt, vx, vy, vz, hdg);
            send = true;
        }

        // =========================================================
        // 11. 文本消息 (Type 20)
        // =========================================================
        else if (type == 20) {
            int severity = obj.value("severity").toInt();
            QJsonArray textArr = obj.value("text").toArray();

            QString rawStr = "";
            for(int i=0; i<textArr.size(); i++) rawStr.append(QChar(textArr[i].toInt()));
            QString decodedStr = unescapeUnicode(rawStr);

            char textBuf[50] = {0};
            QByteArray utf8Bytes = decodedStr.toUtf8();
            int len = qMin((int)utf8Bytes.size(), 49);
            memcpy(textBuf, utf8Bytes.constData(), len);

            mavlink_msg_statustext_pack(1, 1, &msg, (uint8_t)severity, textBuf, 0, 0);
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
        // 15. 距离传感器 (Type 26) -> DISTANCE_SENSOR
        // =========================================================
        else if (type == 26) {
            int dist = obj.value("diatance").toInt(); // 注意拼写是 diatance
            if (dist > 0) {
                mavlink_msg_distance_sensor_pack(1, 1, &msg,
                    0, 0, 10000, dist, MAV_DISTANCE_SENSOR_LASER, 0,
                    MAV_SENSOR_ROTATION_PITCH_270, 0, 0, 0, 0,0);
                send = true;
            }
        }

        if (send) {
            uint16_t len = mavlink_msg_to_send_buffer(buffer, &msg);
            emit dataReceived(QByteArray((char*)buffer, len));
        }
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
             // =========================================================
            // 2. 控制指令翻译 (核心修改部分)
            // =========================================================
            QString jsonCmd;
            uint16_t cmd_ack_id = 0;

            // 提取通用参数 (兼容 COMMAND_LONG 和 COMMAND_INT)
            uint16_t command = 0;
            float param1 = 0;
            float param2 = 0;
            float param7 = 0; // 高度
            double lat_deg = 0;
            double lon_deg = 0;

            if (msg.msgid == MAVLINK_MSG_ID_COMMAND_LONG) {
                mavlink_command_long_t cmd;
                mavlink_msg_command_long_decode(&msg, &cmd);
                command = cmd.command;
                param1 = cmd.param1;
                param2 = cmd.param2;
                param7 = cmd.param7;
                // LONG 里的 param5/6 是经纬度，但在某些指令下可能不同
                lat_deg = cmd.param5;
                lon_deg = cmd.param6;
            }
            else if (msg.msgid == MAVLINK_MSG_ID_COMMAND_INT) {
                mavlink_command_int_t cmd;
                mavlink_msg_command_int_decode(&msg, &cmd);
                command = cmd.command;
                param1 = cmd.param1;
                param2 = cmd.param2;
                param7 = cmd.z;
                lat_deg = (double)cmd.x / 1.0e7;
                lon_deg = (double)cmd.y / 1.0e7;
            }

            if (command != 0) {
                cmd_ack_id = command;

                // --- A. 起飞 (TakeOff) ---
                if (command == MAV_CMD_NAV_TAKEOFF) {
                    float alt = param7 > 0 ? param7 : 5.0f;
                    // 格式: {"byCommand":"TakeOff","alt":5.0}
                    jsonCmd = QString("{\"byCommand\":\"TakeOff\",\"alt\":%1}").arg(alt);
                }

                // --- B. 降落 (Land) ---
                else if (command == MAV_CMD_NAV_LAND) {
                    // 格式: {"byCommand":"Land"}
                    jsonCmd = QString("{\"byCommand\":\"Land\"}");
                }

                // --- C. 解锁/上锁 (Arm/DisArm) ---
                else if (command == MAV_CMD_COMPONENT_ARM_DISARM) {
                    // MAVLink: 1=解锁(Arm), 0=上锁(Disarm)
                    // 厂商: Arm=加锁, DisArm=解锁 (反直觉，必须反转)

                    if (param1 > 0.5f) {
                        // QGC想要解锁 -> 发送厂商的 "DisArm"
                        jsonCmd = QString("{\"byCommand\":\"DisArm\"}");
                    } else {
                        // QGC想要上锁 -> 发送厂商的 "Arm"
                        jsonCmd = QString("{\"byCommand\":\"Arm\"}");
                    }
                }

                // --- D. 返航 (ReturnBack) ---
                else if (command == MAV_CMD_NAV_RETURN_TO_LAUNCH) {
                    // 格式: {"byCommand":"ReturnBack"}
                    jsonCmd = QString("{\"byCommand\":\"ReturnBack\"}");
                }

                // --- E. 指点飞行 (PointingFlight) ---
                // QGC 点击地图"飞到这里"会发送 MAV_CMD_DO_REPOSITION
                else if (command == MAV_CMD_DO_REPOSITION) {
                    // 格式: {"byCommand":"PointingFlight","speed":2.5,"alt":5.0,"lat":5.0,"lon":5.0}
                    float speed = (param2 > 0) ? param2 : 5.0f; // 如果QGC没指定速度，默认5m/s
                    float alt = (param7 != 0) ? param7 : 10.0f; // 高度

                    jsonCmd = QString("{\"byCommand\":\"PointingFlight\",\"speed\":%1,\"alt\":%2,\"lat\":%3,\"lon\":%4}")
                              .arg(speed)
                              .arg(alt)
                              .arg(lat_deg, 0, 'f', 7)
                              .arg(lon_deg, 0, 'f', 7);
                }

                // --- F. 模式切换 (Mode) ---
                else if (command == MAV_CMD_DO_SET_MODE) {
                    int px4Mode = (int)param2;

                    // 厂商支持: Hover (悬停), TakeOff, Land, ReturnBack
                    // 映射策略：
                    if (px4Mode == 196608) { // Altitude (定高)
                        // 厂商没有直接的定高指令，通常切到悬停或不处理
                         jsonCmd = QString("{\"byCommand\":\"Hover\"}");
                    }
                    else if (px4Mode == 262144) { // Position (定点)
                         // 厂商: 悬停
                         jsonCmd = QString("{\"byCommand\":\"Hover\"}");
                    }
                    else if (px4Mode == 84148224) { // RTL
                         jsonCmd = QString("{\"byCommand\":\"ReturnBack\"}");
                    }
                    else if (px4Mode == 50593792) { // Land
                         jsonCmd = QString("{\"byCommand\":\"Land\"}");
                    }
                    else if (px4Mode == 83886080) { // Loiter
                         jsonCmd = QString("{\"byCommand\":\"Hover\"}");
                    }
                    // 注意：厂商没有提供"Manual"指令，如果QGC切手动，这里发不出指令
                }
            }


            // 发送给 JNI 并 回复 ACK
            if (!jsonCmd.isEmpty()) {
                qDebug() << "TX JSON:" << jsonCmd;

                // =========================================================
                // ★★★ 正确做法：调用 Java 层的“总管”方法 ★★★
                // =========================================================
                // QString → Java String
                QJniObject jStr = QJniObject::fromString(jsonCmd);

                QJniObject::callStaticMethod<void>(
                    "org/qjkj/gcs/QGCConnectionManager",
                    "sendData",        // 调用这个公共接口
                    "(Ljava/lang/String;)V", // 参数是 String，返回值 void
                    jStr.object<jstring>()
                );

                // QJniObject jStr = QJniObject::fromString(jsonCmd);
                // QJniObject jBytesObj = _javaSdk.callObjectMethod(
                //     "GetByteByJsonJava", "(Ljava/lang/String;)[B", jStr.object<jstring>()
                // );
                //
                // bool success = false;
                // if (jBytesObj.isValid()) {
                //     jbyteArray jBytes = jBytesObj.object<jbyteArray>();
                //
                //     QJniObject::callStaticMethod<void>(
                //         "org/qjkj/gcs/QGCConnectionManager",
                //         "sendData", "([B)V", jBytes
                //     );
                //     success = true;
                // }

                // ★★★ 核心修复：发送 ACK ★★★
                if (cmd_ack_id != 0) {
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

    QJniObject::callStaticMethod<void>(
        "org/qjkj/gcs/QGCConnectionManager",
        "stopConnection",
        "()V"
    );
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

    // 4. ★★★ 绑定信号槽 (主线程 <-> 子线程) ★★★

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