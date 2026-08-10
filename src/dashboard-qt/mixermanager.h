#ifndef MIXERMANAGER_H
#define MIXERMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QTimer>

class MixerManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.josue.mixer")
    Q_PROPERTY(QVariantList streams READ streams NOTIFY streamsChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    explicit MixerManager(QObject *parent = nullptr);

    QVariantList streams() const { return m_streams; }

    bool active() const { return m_active; }
    void setActive(bool active);

    bool scanning() const { return m_scanning; }

public slots:
    Q_SCRIPTABLE void toggle();
    Q_SCRIPTABLE void refresh();
    Q_SCRIPTABLE void setVolume(int id, float volume);
    Q_SCRIPTABLE void setMute(int id, bool mute);

signals:
    void streamsChanged();
    void activeChanged();
    void scanningChanged();

private slots:
    void onTimerTimeout();

private:
    QVariantList m_streams;
    bool m_active = false;
    bool m_scanning = false;
    QTimer m_timer;
};

#endif // MIXERMANAGER_H
