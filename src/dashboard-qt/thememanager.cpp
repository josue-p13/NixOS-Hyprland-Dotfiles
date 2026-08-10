#include "thememanager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QDebug>
#include <QTimer>

ThemeManager::ThemeManager(QObject *parent)
    : QObject(parent)
{
    m_colorsPath = QDir::homePath() + "/.cache/wallust/colors.json";
    
    // Load initial colors
    loadColors();
    
    // Setup file watcher
    if (QFile::exists(m_colorsPath)) {
        m_watcher.addPath(m_colorsPath);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &ThemeManager::onFileChanged);
    }
}

QVariantMap ThemeManager::colors() const
{
    return m_colors;
}

void ThemeManager::onFileChanged(const QString &path)
{
    Q_UNUSED(path);
    
    // Slight delay to ensure the writing process has completely finished
    QTimer::singleShot(100, this, [this]() {
        loadColors();
        
        // Re-add path in case the file was replaced atomatically
        if (QFile::exists(m_colorsPath) && !m_watcher.files().contains(m_colorsPath)) {
            m_watcher.addPath(m_colorsPath);
        }
    });
}

void ThemeManager::loadColors()
{
    QFile file(m_colorsPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Could not open colors.json, using fallback colors.";
        
        // Fallback to default Gruvbox colors
        m_colors.clear();
        m_colors["background"] = "#282828";
        m_colors["foreground"] = "#ebdbb2";
        m_colors["cursor"] = "#fe8019";
        
        QVariantMap subColors;
        subColors["color0"] = "#282828";
        subColors["color1"] = "#cc241d";
        subColors["color2"] = "#98971a";
        subColors["color3"] = "#d79921";
        subColors["color4"] = "#458588";
        subColors["color5"] = "#b16286";
        subColors["color6"] = "#689d6a";
        subColors["color7"] = "#a89984";
        subColors["color8"] = "#928374";
        subColors["color9"] = "#fb4934";
        subColors["color10"] = "#b8bb26";
        subColors["color11"] = "#fabd2f";
        subColors["color12"] = "#83a598";
        subColors["color13"] = "#d3869b";
        subColors["color14"] = "#8ec07c";
        subColors["color15"] = "#ebdbb2";
        m_colors["colors"] = subColors;
        
        emit colorsChanged();
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "Invalid colors.json format.";
        return;
    }

    QJsonObject obj = doc.object();
    m_colors = obj.toVariantMap();
    
    emit colorsChanged();
}
