#ifndef DASHBOARDMANAGER_H
#define DASHBOARDMANAGER_H

#include <QObject>

class DashboardManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.josue.dashboard")
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit DashboardManager(QObject *parent = nullptr);

    bool active() const { return m_active; }
    void setActive(bool active);

public slots:
    Q_SCRIPTABLE void toggle();

signals:
    void activeChanged();

private:
    bool m_active = false;
};

#endif // DASHBOARDMANAGER_H
