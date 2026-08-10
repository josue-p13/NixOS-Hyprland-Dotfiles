#include "monitormanager.h"
#include <QProcess>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDebug>

MonitorManager::MonitorManager(QObject *parent)
    : QObject(parent)
{
    // Initial query
    refresh();
}

void MonitorManager::setActive(bool active)
{
    if (m_active != active) {
        m_active = active;
        emit activeChanged();
        if (m_active) {
            refresh();
        }
    }
}

void MonitorManager::toggle()
{
    setActive(!m_active);
}

void MonitorManager::refresh()
{
    QProcess process;
    process.start("hyprctl", QStringList() << "monitors" << "all" << "-j");
    if (!process.waitForFinished(3000)) {
        qWarning() << "hyprctl monitors command timed out";
        return;
    }

    QByteArray output = process.readAllStandardOutput();
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "Failed to parse hyprctl output:" << parseError.errorString();
        return;
    }

    if (!doc.isArray()) {
        qWarning() << "Expected JSON array from hyprctl monitors";
        return;
    }

    QJsonArray arr = doc.array();
    QVariantList newMonitors;

    for (int i = 0; i < arr.size(); ++i) {
        QJsonObject obj = arr.at(i).toObject();
        QVariantMap mon;
        mon["name"] = obj.value("name").toString();
        mon["description"] = obj.value("description").toString();
        mon["width"] = obj.value("width").toInt();
        mon["height"] = obj.value("height").toInt();
        mon["x"] = obj.value("x").toInt();
        mon["y"] = obj.value("y").toInt();
        mon["refreshRate"] = obj.value("refreshRate").toDouble();
        mon["scale"] = obj.value("scale").toDouble();
        mon["transform"] = obj.value("transform").toInt();
        mon["focused"] = obj.value("focused").toBool();
        mon["disabled"] = obj.value("disabled").toBool();

        QJsonArray modesArr = obj.value("availableModes").toArray();
        QStringList modes;
        for (int j = 0; j < modesArr.size(); ++j) {
            modes.append(modesArr.at(j).toString());
        }
        mon["availableModes"] = modes;

        newMonitors.append(mon);
    }

    m_monitors = newMonitors;
    emit monitorsChanged();
}

void MonitorManager::applyConfig(const QVariantList &monitorConfigs)
{
    QString configContent;
    QStringList batchCmds;
    QString summary;

    for (const QVariant &item : monitorConfigs) {
        QVariantMap mon = item.toMap();
        QString name = mon["name"].toString();
        bool disabled = mon["disabled"].toBool();

        if (disabled) {
            configContent += QString("monitor=%1,disable\n").arg(name);
            batchCmds.append(QString("keyword monitor %1,disable").arg(name));
            summary += QString("%1 (Disabled) ").arg(name);
        } else {
            int resW = mon["resW"].toInt();
            int resH = mon["resH"].toInt();
            QString rate = mon["rate"].toString();
            int x = mon["x"].toInt();
            int y = mon["y"].toInt();
            double scale = mon["sysScale"].toDouble();
            if (scale <= 0.0) scale = 1.0;
            int transform = mon["transform"].toInt();

            QString monitorStr = QString("%1,%2x%3@%4,%5x%6,%7").arg(name).arg(resW).arg(resH).arg(rate).arg(x).arg(y).arg(scale);
            if (transform != 0) {
                monitorStr += QString(",transform,%1").arg(transform);
            }

            configContent += QString("monitor=%1\n").arg(monitorStr);
            batchCmds.append(QString("keyword monitor %1").arg(monitorStr));
            summary += QString("%1 (%2x%3@%4Hz) ").arg(name).arg(resW).arg(resH).arg(rate);
        }
    }

    // Write to monitors.conf for persistence
    QString configPath = QDir::homePath() + "/.cache/hypr/monitors.conf";
    QFile file(configPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << configContent;
        file.close();
        qDebug() << "Wrote monitor configuration to" << configPath;
    } else {
        qWarning() << "Failed to write to" << configPath << ":" << file.errorString();
    }

    // Apply immediately via hyprctl
    QString batchArgs = batchCmds.join(" ; ");
    QProcess::startDetached("hyprctl", QStringList() << "--batch" << batchArgs);

    // Send notification
    QProcess::startDetached("notify-send", QStringList() << "Configuración de Pantalla" << QString("Ajustes aplicados para: %1").arg(summary));

    // Hide window after applying
    setActive(false);
}
