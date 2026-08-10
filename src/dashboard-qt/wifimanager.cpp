#include "wifimanager.h"
#include <QProcess>
#include <QProcessEnvironment>
#include <QNetworkInterface>
#include <QNetworkAddressEntry>
#include <QHostAddress>
#include <QDebug>
#include <QThread>

WifiManager::WifiManager(QObject *parent)
    : QObject(parent)
{
    updatePowerState();
    refresh();
}

bool WifiManager::hasProfile(const QString &ssid)
{
    QProcess checkProc;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    checkProc.setProcessEnvironment(env);
    checkProc.start("nmcli", QStringList() << "-t" << "-f" << "NAME" << "connection" << "show");
    if (checkProc.waitForFinished(1000)) {
        QString out = QString::fromUtf8(checkProc.readAllStandardOutput());
        QStringList connections = out.split('\n', Qt::SkipEmptyParts);
        for (const QString &conn : connections) {
            if (conn.trimmed() == ssid) {
                return true;
            }
        }
    }
    return false;
}

void WifiManager::setActive(bool active)
{
    if (m_active != active) {
        m_active = active;
        emit activeChanged();
        if (m_active) {
            updatePowerState();
            refresh();
        }
    }
}

void WifiManager::toggle()
{
    setActive(!m_active);
}

void WifiManager::updatePowerState()
{
    QProcess process;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process.setProcessEnvironment(env);
    process.start("nmcli", QStringList() << "radio" << "wifi");
    if (process.waitForFinished(1000)) {
        QString out = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        bool power = (out == "enabled");
        if (m_wifiPower != power) {
            m_wifiPower = power;
            emit wifiPowerChanged();
        }
    }
}

void WifiManager::setWifiPower(bool power)
{
    QProcess process;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process.setProcessEnvironment(env);
    process.start("nmcli", QStringList() << "radio" << "wifi" << (power ? "on" : "off"));
    if (process.waitForFinished(2000)) {
        m_wifiPower = power;
        emit wifiPowerChanged();
        if (power) {
            QThread::msleep(500); // Give hardware a moment to power on
            refresh();
        } else {
            m_networks.clear();
            emit networksChanged();
        }
    }
}

void WifiManager::refresh()
{
    if (m_scanning) return;

    m_scanning = true;
    emit scanningChanged();

    // Trigger an asynchronous scan/list
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("nmcli", QStringList() << "-t" << "-f" << "active,ssid,signal,security" << "dev" << "wifi" << "list");

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        m_scanning = false;
        emit scanningChanged();

        if (exitCode != 0 || status == QProcess::CrashExit) {
            qWarning() << "nmcli dev wifi list command failed";
            return;
        }

        QByteArray output = process->readAllStandardOutput();
        QStringList lines = QString::fromUtf8(output).split('\n', Qt::SkipEmptyParts);

        QVariantList newList;
        QSet<QString> seenSsids;

        // Fetch local WiFi IP natively
        QString localIp = "No IP";
        for (const QNetworkInterface &interface : QNetworkInterface::allInterfaces()) {
            if (interface.flags().testFlag(QNetworkInterface::IsUp) && 
                !interface.flags().testFlag(QNetworkInterface::IsLoopBack) &&
                interface.name().startsWith("wl")) {
                for (const QNetworkAddressEntry &entry : interface.addressEntries()) {
                    if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol) {
                        localIp = entry.ip().toString();
                        break;
                    }
                }
            }
        }

        for (const QString &line : lines) {
            QStringList fields = line.split(':');
            if (fields.size() < 4) continue;

            QString activeField = fields.at(0).trimmed().toLower();
            QString ssid = fields.at(1);
            if (ssid.isEmpty()) continue;

            if (seenSsids.contains(ssid)) continue;
            seenSsids.insert(ssid);

            int signal = fields.at(2).toInt();
            QString security = fields.at(3);
            bool secured = (!security.isEmpty() && security != "--");
            bool connected = (activeField == "yes" || activeField == "si" || activeField == "sí");

            QVariantMap net;
            net["ssid"] = ssid;
            net["signal"] = signal;
            net["secured"] = secured;
            net["connected"] = connected;
            net["security"] = security;
            
            if (connected) {
                net["ip"] = localIp;
            } else {
                net["ip"] = "";
            }

            newList.append(net);
        }

        m_networks = newList;
        emit networksChanged();
    });
}

void WifiManager::connectToNetwork(const QString &ssid, const QString &password)
{
    if (m_connectingSsid != "") return; // Busy

    m_connectingSsid = ssid;
    emit connectingSsidChanged();

    // Check if the connection profile already exists
    QProcess *checkProc = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    checkProc->setProcessEnvironment(env);
    checkProc->start("nmcli", QStringList() << "-t" << "-f" << "NAME" << "connection" << "show");
    
    connect(checkProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, checkProc, ssid, password](int exitCode, QProcess::ExitStatus status) {
        checkProc->deleteLater();
        if (exitCode != 0 || status == QProcess::CrashExit) {
            m_connectingSsid = "";
            emit connectingSsidChanged();
            return;
        }

        QString out = QString::fromUtf8(checkProc->readAllStandardOutput());
        QStringList connections = out.split('\n', Qt::SkipEmptyParts);
        bool hasProfile = false;
        for (const QString &conn : connections) {
            if (conn.trimmed() == ssid) {
                hasProfile = true;
                break;
            }
        }

        QProcess *connectProc = new QProcess(this);
        QProcessEnvironment connectEnv = QProcessEnvironment::systemEnvironment();
        connectEnv.insert("LC_ALL", "C");
        connectProc->setProcessEnvironment(connectEnv);

        QStringList args;
        if (hasProfile) {
            args << "connection" << "up" << "id" << ssid;
        } else {
            args << "device" << "wifi" << "connect" << ssid;
            if (!password.isEmpty()) {
                args << "password" << password;
            }
        }

        connectProc->start("nmcli", args);
        connect(connectProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, connectProc, ssid, hasProfile](int exitCode, QProcess::ExitStatus status) {
            connectProc->deleteLater();
            m_connectingSsid = "";
            emit connectingSsidChanged();

            if (exitCode == 0 && status == QProcess::NormalExit) {
                QProcess::startDetached("notify-send", QStringList() << "Wi-Fi" << QString("Conectado con éxito a %1").arg(ssid));
            } else {
                QProcess::startDetached("notify-send", QStringList() << "Wi-Fi" << QString("Error al conectar a %1").arg(ssid));
                if (!hasProfile) {
                    QProcess::execute("nmcli", QStringList() << "connection" << "delete" << ssid);
                }
            }
            refresh();
        });
    });
}

void WifiManager::disconnectNetwork(const QString &ssid)
{
    QProcess *proc = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    proc->setProcessEnvironment(env);
    proc->start("nmcli", QStringList() << "connection" << "down" << "id" << ssid);
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, proc, ssid]() {
        proc->deleteLater();
        QProcess::startDetached("notify-send", QStringList() << "Wi-Fi" << QString("Desconectado de %1").arg(ssid));
        refresh();
    });
}
