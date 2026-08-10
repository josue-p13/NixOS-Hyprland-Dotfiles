#ifndef AUDIOMANAGER_H
#define AUDIOMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class AudioManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.josue.audio")
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    explicit AudioManager(QObject *parent = nullptr);

    QVariantList devices() const { return m_devices; }

    bool active() const { return m_active; }
    void setActive(bool active);

    bool scanning() const { return m_scanning; }

public slots:
    Q_SCRIPTABLE void toggle();
    Q_SCRIPTABLE void refresh();
    Q_SCRIPTABLE void setDefaultDevice(const QString &id);
    Q_SCRIPTABLE void setVolume(const QString &id, float volume);
    Q_SCRIPTABLE void setMute(const QString &id, bool mute);

signals:
    void devicesChanged();
    void activeChanged();
    void scanningChanged();

private:
    QVariantList m_devices;
    bool m_active = false;
    bool m_scanning = false;
};

#endif // AUDIOMANAGER_H
