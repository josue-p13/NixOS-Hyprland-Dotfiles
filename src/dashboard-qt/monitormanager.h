#ifndef MONITORMANAGER_H
#define MONITORMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class MonitorManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.josue.monitor")
    Q_PROPERTY(QVariantList monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit MonitorManager(QObject *parent = nullptr);

    QVariantList monitors() const { return m_monitors; }
    bool active() const { return m_active; }
    void setActive(bool active);

public slots:
    Q_SCRIPTABLE void toggle();
    Q_SCRIPTABLE void refresh();
    Q_SCRIPTABLE void applyConfig(const QVariantList &monitorConfigs);

signals:
    void monitorsChanged();
    void activeChanged();

private:
    QVariantList m_monitors;
    bool m_active = false;
};

#endif // MONITORMANAGER_H
