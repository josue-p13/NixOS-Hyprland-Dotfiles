#include "bluetoothmanager.h"
#include <QProcess>
#include <QProcessEnvironment>
#include <QDebug>
#include <QThread>

BluetoothManager::BluetoothManager(QObject *parent)
    : QObject(parent)
{
    updatePowerState();
    refresh();
}

void BluetoothManager::setActive(bool active)
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

void BluetoothManager::toggle()
{
    setActive(!m_active);
}

void BluetoothManager::updatePowerState()
{
    QProcess process;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process.setProcessEnvironment(env);
    process.start("bash", QStringList() << "-c" << "echo 'show' | bluetoothctl");
    if (process.waitForFinished(2000)) {
        QString out = QString::fromUtf8(process.readAllStandardOutput());
        bool power = out.contains("Powered: yes");
        if (m_bluetoothPower != power) {
            m_bluetoothPower = power;
            emit bluetoothPowerChanged();
        }
    }
}

void BluetoothManager::setBluetoothPower(bool power)
{
    QProcess process;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process.setProcessEnvironment(env);
    process.start("bash", QStringList() << "-c" << QString("echo 'power %1' | bluetoothctl").arg(power ? "on" : "off"));
    if (process.waitForFinished(2000)) {
        m_bluetoothPower = power;
        emit bluetoothPowerChanged();
        if (power) {
            QThread::msleep(500); // Give hardware a moment to power on
            refresh();
        } else {
            m_devices.clear();
            emit devicesChanged();
        }
    }
}

void BluetoothManager::refresh()
{
    if (m_scanning) return;

    m_scanning = true;
    emit scanningChanged();

    // Compile our bash script inline using piped bluetoothctl commands
    QString script = 
        "conn_macs=$(echo 'devices Connected' | bluetoothctl | grep 'Device ' | awk '{print $2}'); "
        "paired_macs=$(echo 'devices Paired' | bluetoothctl | grep 'Device ' | awk '{print $2}'); "
        "echo 'devices' | bluetoothctl | while read -r line; do "
        "  [ -z \"$line\" ] && continue; "
        "  [[ \"$line\" != *\"Device \"* ]] && continue; "
        "  mac=$(echo \"$line\" | awk '{print $2}'); "
        "  name=$(echo \"$line\" | cut -d' ' -f3-); "
        "  status=\"available\"; "
        "  if [[ \"$conn_macs\" == *\"$mac\"* ]]; then "
        "    status=\"connected\"; "
        "  elif [[ \"$paired_macs\" == *\"$mac\"* ]]; then "
        "    status=\"paired\"; "
        "  fi; "
        "  battery=\"0\"; "
        "  icon=\"bluetooth\"; "
        "  if [ \"$status\" == \"connected\" ]; then "
        "    info=$(echo \"info $mac\" | bluetoothctl); "
        "    bat=$(echo \"$info\" | awk -F'[(|)]' '/Battery Percentage:/ {print $2}'); "
        "    [ -z \"$bat\" ] && battery=\"0\" || battery=\"$bat\"; "
        "    icon_type=$(echo \"$info\" | awk -F': ' '/Icon:/ {print $2}'); "
        "    icon_type=${icon_type,,}; "
        "    name_lower=${name,,}; "
        "    if [[ \"$icon_type\" == *\"headset\"* || \"$icon_type\" == *\"headphone\"* || \"$name_lower\" == *\"headphone\"* || \"$name_lower\" == *\"buds\"* || \"$name_lower\" == *\"pods\"* ]]; then icon=\"headset\"; "
        "    elif [[ \"$icon_type\" == *\"audio\"* || \"$icon_type\" == *\"speaker\"* || \"$name_lower\" == *\"speaker\"* ]]; then icon=\"audio\"; "
        "    elif [[ \"$icon_type\" == *\"phone\"* || \"$name_lower\" == *\"phone\"* ]]; then icon=\"phone\"; "
        "    elif [[ \"$icon_type\" == *\"mouse\"* || \"$name_lower\" == *\"mouse\"* ]]; then icon=\"mouse\"; "
        "    elif [[ \"$icon_type\" == *\"keyboard\"* || \"$name_lower\" == *\"keyboard\"* ]]; then icon=\"keyboard\"; "
        "    elif [[ \"$icon_type\" == *\"controller\"* || \"$name_lower\" == *\"controller\"* ]]; then icon=\"gamepad\"; "
        "    fi; "
        "  fi; "
        "  echo \"$status|$mac|$name|$battery|$icon\"; "
        "done";

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("bash", QStringList() << "-c" << script);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        m_scanning = false;
        emit scanningChanged();

        if (exitCode != 0 || status == QProcess::CrashExit) {
            qWarning() << "Bluetooth list devices query failed";
            return;
        }

        QByteArray output = process->readAllStandardOutput();
        QStringList lines = QString::fromUtf8(output).split('\n', Qt::SkipEmptyParts);

        QVariantList newList;
        for (const QString &line : lines) {
            QStringList fields = line.split('|');
            if (fields.size() < 5) continue;

            QString deviceStatus = fields.at(0);
            QString mac = fields.at(1);
            QString name = fields.at(2);
            int battery = fields.at(3).toInt();
            QString icon = fields.at(4);

            QVariantMap dev;
            dev["status"] = deviceStatus;
            dev["mac"] = mac;
            dev["name"] = name;
            dev["battery"] = battery;
            dev["icon"] = icon;
            dev["connected"] = (deviceStatus == "connected");
            dev["paired"] = (deviceStatus == "paired" || deviceStatus == "connected");

            newList.append(dev);
        }

        m_devices = newList;
        emit devicesChanged();
    });
}

void BluetoothManager::connectDevice(const QString &mac)
{
    if (m_connectingMac != "") return; // Busy

    m_connectingMac = mac;
    emit connectingMacChanged();

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    
    // Command to trust and connect device using piped bluetoothctl commands
    QString cmd = QString("echo -e 'trust %1\\nconnect %1' | bluetoothctl").arg(mac);
    process->start("bash", QStringList() << "-c" << cmd);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process, mac](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        m_connectingMac = "";
        emit connectingMacChanged();

        if (exitCode == 0 && status == QProcess::NormalExit) {
            QProcess::startDetached("notify-send", QStringList() << "Bluetooth" << QString("Conectado con éxito al dispositivo"));
        } else {
            QProcess::startDetached("notify-send", QStringList() << "Bluetooth" << QString("Error al conectar el dispositivo"));
        }
        refresh();
    });
}

void BluetoothManager::disconnectDevice(const QString &mac)
{
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("bash", QStringList() << "-c" << QString("echo 'disconnect %1' | bluetoothctl").arg(mac));

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process, mac](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        if (exitCode == 0 && status == QProcess::NormalExit) {
            QProcess::startDetached("notify-send", QStringList() << "Bluetooth" << QString("Dispositivo desconectado"));
        }
        refresh();
    });
}
