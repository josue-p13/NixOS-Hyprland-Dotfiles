#include "dashboardmanager.h"

DashboardManager::DashboardManager(QObject *parent)
    : QObject(parent)
{
}

void DashboardManager::toggle()
{
    setActive(!m_active);
}

void DashboardManager::setActive(bool active)
{
    if (m_active != active) {
        m_active = active;
        emit activeChanged();
    }
}
