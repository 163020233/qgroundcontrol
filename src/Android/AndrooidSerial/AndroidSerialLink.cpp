//
// Created by Administrator on 25-7-30.
//
#include "AndroidSerialLink.h"

#ifdef Q_OS_ANDROID

#include <QCoreApplication>
#include <QJniEnvironment>
#include <QByteArray>
#include <QtCore/qnativeinterface.h>

AndroidSerialLink::AndroidSerialLink(QObject* parent)
    : QObject(parent)
{
    // 获取 Android Activity 对象
    jobject activity = QJniObject(QNativeInterface::QAndroidApplication::context()).object<jobject>();

            // 调用 Java 构造函数
    m_androidSerial = QJniObject("org/qjkj/gcs/AndroidSerial",
                                 "(Landroid/content/Context;)V",
                                 activity);

    if (!m_androidSerial.isValid()) {
        qWarning() << "Failed to create AndroidSerial Java object";
    }
}

AndroidSerialLink::~AndroidSerialLink()
{
    close();
}

bool AndroidSerialLink::open()
{
    // 你已经在构造函数中打开了端口，所以这里可空
    return m_androidSerial.isValid();
}

bool AndroidSerialLink::writeData(const QByteArray& data)
{
    if (!m_androidSerial.isValid())
        return false;

    QJniEnvironment env;
    jbyteArray byteArray = env->NewByteArray(data.size());
    env->SetByteArrayRegion(byteArray, 0, data.size(), reinterpret_cast<const jbyte*>(data.constData()));

    jint result = m_androidSerial.callMethod<jint>("write", "([B)I", byteArray);

    env->DeleteLocalRef(byteArray);

    return result == data.size();
}

void AndroidSerialLink::close()
{
    if (m_androidSerial.isValid()) {
        m_androidSerial.callMethod<void>("close", "()V");
    }
}

#endif
