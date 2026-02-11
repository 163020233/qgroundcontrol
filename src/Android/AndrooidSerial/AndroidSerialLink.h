#ifndef ANDROIDSERIALLINK_H
#define ANDROIDSERIALLINK_H

#include <QObject>

#ifdef Q_OS_ANDROID
#include <QJniObject>

class AndroidSerialLink : public QObject
{
    Q_OBJECT
   public:
    explicit AndroidSerialLink(QObject* parent = nullptr);
    ~AndroidSerialLink();

    bool open();
    bool writeData(const QByteArray& data);
    void close();

   private:
    QJniObject m_androidSerial;
};

#endif // Q_OS_ANDROID
#endif // ANDROIDSERIALLINK_H

