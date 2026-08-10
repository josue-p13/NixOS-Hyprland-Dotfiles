#include "systemmonitor.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QDebug>
#include <QRegularExpression>
#include <sys/statvfs.h>
#include <iostream>

SystemMonitor::SystemMonitor(QObject *parent)
    : QObject(parent)
{
    // 1. Detect if nvidia-smi exists
    m_hasNvidiaSmi = !QStandardPaths::findExecutable("nvidia-smi").isEmpty();
    if (m_hasNvidiaSmi) {
        m_gpuProcess = new QProcess(this);
        connect(m_gpuProcess, &QProcess::finished, this, &SystemMonitor::onGpuProcessFinished);
    }

    // 2. Locate CPU temperature sensor path in /sys/class/hwmon/
    QDir hwmonDir("/sys/class/hwmon");
    QStringList subdirs = hwmonDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    // We try to find coretemp (Intel) or k10temp/zenpower (AMD) or cpu_thermal (ARM)
    QString fallbackPath;
    for (const QString &subdir : subdirs) {
        QString path = hwmonDir.absoluteFilePath(subdir);
        QFile nameFile(path + "/name");
        QString name;
        if (nameFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            name = nameFile.readAll().trimmed().toLower();
            nameFile.close();
        }

        // Check for temp1_input or temp2_input
        QDir subdirDir(path);
        QStringList tempFiles = subdirDir.entryList(QStringList("temp*_input"), QDir::Files);
        if (!tempFiles.isEmpty()) {
            // Sort to get a consistent sensor (usually temp1_input or temp2_input is the package temperature)
            tempFiles.sort();
            QString selectedTempFile = tempFiles.first();
            
            // Prefer package temp if coretemp
            if (name == "coretemp") {
                for (const QString &tf : tempFiles) {
                    if (tf.contains("temp1_input") || tf.contains("temp2_input")) {
                        selectedTempFile = tf;
                    }
                }
            }

            QString fullPath = path + "/" + selectedTempFile;
            if (name == "coretemp" || name == "k10temp" || name == "zenpower" || name == "cpu_thermal" || name == "acpitz") {
                m_tempPath = fullPath;
                break; // Found preferred CPU temperature sensor
            } else if (fallbackPath.isEmpty()) {
                fallbackPath = fullPath;
            }
        }
    }

    if (m_tempPath.isEmpty()) {
        m_tempPath = fallbackPath;
    }

    // 3. Initialize network values
    m_prevNetTime = QDateTime::currentMSecsSinceEpoch();
    updateNet();

    // 4. Run the first statistics poll
    updateStats();

    // 5. Connect timer to run every 2000ms (2 seconds)
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::updateStats);
    m_timer.start(2000);
}

void SystemMonitor::updateStats()
{
    updateCpu();
    updateRam();
    updateTemp();
    updateGpu();
    updateDisk();
    updateNet();
    updateFace();
}

void SystemMonitor::updateCpu()
{
    QFile file("/proc/stat");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream in(&file);
    QString line = in.readLine();
    file.close();

    if (!line.startsWith("cpu "))
        return;

    // Parse the cpu fields
    QStringList fields = line.split(QRegularExpression("\\s+"), Qt::KeepEmptyParts);
    if (fields.size() < 5)
        return;

    // Fields: cpu, user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice
    // index 1 is user, 2 nice, 3 system, 4 idle, 5 iowait, etc.
    unsigned long long user = fields[1].toULongLong();
    unsigned long long nice = fields[2].toULongLong();
    unsigned long long system = fields[3].toULongLong();
    unsigned long long idle = fields[4].toULongLong();
    unsigned long long iowait = fields.size() > 5 ? fields[5].toULongLong() : 0;
    unsigned long long irq = fields.size() > 6 ? fields[6].toULongLong() : 0;
    unsigned long long softirq = fields.size() > 7 ? fields[7].toULongLong() : 0;
    unsigned long long steal = fields.size() > 8 ? fields[8].toULongLong() : 0;

    unsigned long long activeTime = user + nice + system + irq + softirq + steal;
    unsigned long long idleTime = idle + iowait;
    unsigned long long totalTime = activeTime + idleTime;

    if (m_prevTotal > 0) {
        unsigned long long totalDelta = totalTime - m_prevTotal;
        unsigned long long activeDelta = activeTime - m_prevActive;
        
        if (totalDelta > 0) {
            double cpuVal = (double)activeDelta / totalDelta * 100.0;
            if (cpuVal < 0.0) cpuVal = 0.0;
            if (cpuVal > 100.0) cpuVal = 100.0;
            
            if (qAbs(m_cpu - cpuVal) > 0.1) {
                m_cpu = cpuVal;
                emit cpuChanged();
            }
        }
    }

    m_prevActive = activeTime;
    m_prevTotal = totalTime;
}

void SystemMonitor::updateRam()
{
    QFile file("/proc/meminfo");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QString data = file.readAll();
    file.close();

    unsigned long long totalMem = 0;
    unsigned long long availMem = 0;
    unsigned long long freeMem = 0;
    unsigned long long cachedMem = 0;
    unsigned long long buffersMem = 0;

    QStringList lines = data.split('\n');
    for (const QString &line : lines) {
        if (line.startsWith("MemTotal:")) {
            totalMem = line.split(QRegularExpression("\\s+"))[1].toULongLong(); // in kB
        } else if (line.startsWith("MemAvailable:")) {
            availMem = line.split(QRegularExpression("\\s+"))[1].toULongLong(); // in kB
        } else if (line.startsWith("MemFree:")) {
            freeMem = line.split(QRegularExpression("\\s+"))[1].toULongLong(); // in kB
        } else if (line.startsWith("Cached:")) {
            cachedMem = line.split(QRegularExpression("\\s+"))[1].toULongLong(); // in kB
        } else if (line.startsWith("Buffers:")) {
            buffersMem = line.split(QRegularExpression("\\s+"))[1].toULongLong(); // in kB
        }
    }

    if (totalMem == 0)
        return;

    // Use MemAvailable if present, else fallback
    unsigned long long freeBytes = availMem > 0 ? availMem : (freeMem + buffersMem + cachedMem);
    unsigned long long usedBytes = totalMem - freeBytes;
    double ramVal = (double)usedBytes / totalMem * 100.0;

    if (qAbs(m_ram - ramVal) > 0.1) {
        m_ram = ramVal;
        emit ramChanged();
    }
}

void SystemMonitor::updateTemp()
{
    if (m_tempPath.isEmpty())
        return;

    QFile file(m_tempPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    double tempVal = file.readAll().trimmed().toDouble() / 1000.0;
    file.close();

    if (qAbs(m_temp - tempVal) > 0.1) {
        m_temp = tempVal;
        emit tempChanged();
    }
}

void SystemMonitor::updateGpu()
{
    if (!m_hasNvidiaSmi || !m_gpuProcess)
        return;

    // If the process is already running, skip this tick to avoid pile-up
    if (m_gpuProcess->state() != QProcess::NotRunning)
        return;

    m_gpuProcess->start("nvidia-smi", QStringList() << "--query-gpu=utilization.gpu" << "--format=csv,noheader");
}

void SystemMonitor::onGpuProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (exitCode == 0 && exitStatus == QProcess::NormalExit) {
        QString output = m_gpuProcess->readAllStandardOutput().trimmed();
        output.remove('%');
        double gpuVal = output.toDouble();
        if (qAbs(m_gpu - gpuVal) > 0.1) {
            m_gpu = gpuVal;
            emit gpuChanged();
        }
    } else {
        // Fallback or ignore
        if (m_gpu != 0.0) {
            m_gpu = 0.0;
            emit gpuChanged();
        }
    }
}

void SystemMonitor::updateDisk()
{
    struct statvfs stat;
    if (statvfs("/", &stat) == 0) {
        unsigned long long total = stat.f_blocks * stat.f_frsize;
        unsigned long long free = stat.f_bavail * stat.f_frsize;
        if (total > 0) {
            double diskVal = (double)(total - free) / total * 100.0;
            if (qAbs(m_disk - diskVal) > 0.1) {
                m_disk = diskVal;
                emit diskChanged();
            }
        }
    }
}

void SystemMonitor::updateNet()
{
    QFile file("/proc/net/dev");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream in(&file);
    unsigned long long totalRx = 0;
    unsigned long long totalTx = 0;

    // Skip the first two header lines
    in.readLine();
    in.readLine();

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith("lo:"))
            continue;

        int colonIdx = line.indexOf(':');
        if (colonIdx == -1)
            continue;

        QString statsPart = line.mid(colonIdx + 1).trimmed();
        QStringList tokens = statsPart.split(QRegularExpression("\\s+"));
        if (tokens.size() >= 9) {
            // Index 0 is Rx bytes, Index 8 is Tx bytes
            totalRx += tokens[0].toULongLong();
            totalTx += tokens[8].toULongLong();
        }
    }
    file.close();

    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    qint64 timeDeltaMs = currentTime - m_prevNetTime;

    if (timeDeltaMs > 0 && m_prevRxBytes > 0) {
        double rxRateVal = (double)(totalRx - m_prevRxBytes) / (timeDeltaMs / 1000.0);
        double txRateVal = (double)(totalTx - m_prevTxBytes) / (timeDeltaMs / 1000.0);
        
        if (rxRateVal < 0) rxRateVal = 0;
        if (txRateVal < 0) txRateVal = 0;

        m_rxRate = rxRateVal;
        m_txRate = txRateVal;
        emit netChanged();
    }

    m_prevRxBytes = totalRx;
    m_prevTxBytes = totalTx;
    m_prevNetTime = currentTime;
}

void SystemMonitor::updateFace()
{
    // Determine kawaii face based on highest load
    double maxLoad = qMax(m_cpu, qMax(m_gpu, m_temp - 30.0));
    QString newFace;
    if (maxLoad > 90) {
        newFace = "(＃＞＜)";
    } else if (maxLoad > 70) {
        newFace = "(・_・;)";
    } else if (maxLoad > 50) {
        newFace = "( ˶ˆ꒳ˆ˵ )";
    } else if (maxLoad > 25) {
        newFace = "( ˶'ᵕ'˶ )";
    } else {
        newFace = "( ˶ˆ꒳ˆ˵ )♡";
    }

    if (m_face != newFace) {
        m_face = newFace;
        emit faceChanged();
    }
}
