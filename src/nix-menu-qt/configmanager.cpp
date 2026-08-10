#include "configmanager.h"
#include <QProcess>
#include <QDir>
#include <QVariantMap>
#include <QCoreApplication>

ConfigManager::ConfigManager(QObject *parent)
    : QObject(parent)
{
}

QVariantList ConfigManager::getConfigs() const
{
    QVariantList list;

    auto addConfig = [&](const QString &name, const QString &path, const QString &icon) {
        QVariantMap map;
        map["name"] = name;
        map["path"] = path;
        map["icon"] = icon;
        list.append(map);
    };

    addConfig("NixOS Config", "/etc/nixos/configuration.nix", "");
    addConfig("NixOS Flake", "/etc/nixos/flake.nix", "");
    addConfig("Hyprland", "~/.config/hypr/hyprland.conf", "");
    addConfig("Waybar", "~/.config/waybar/config", "");
    addConfig("Waybar Style", "~/.config/waybar/style.css", "󰏘");
    addConfig("SwayNC", "~/.config/swaync/config.json", "");
    addConfig("Ghostty", "~/.config/ghostty/config", "");

    return list;
}

void ConfigManager::editConfig(const QString &name, const QString &path)
{
    QString resolvedPath = path;
    if (resolvedPath.startsWith("~")) {
        resolvedPath.replace(0, 1, QDir::homePath());
    }

    if (name.startsWith("NixOS")) {
        // Para NixOS: editar con sudo y luego realizar nixos-rebuild switch de forma integrada
        QString cmdStr = QString(
            "sudo nvim %1 && cd /etc/nixos && sudo git add . && sudo nixos-rebuild switch --flake .#nixos; "
            "echo ''; echo 'Reconstrucción completada. Presiona Enter para cerrar...'; read"
        ).arg(resolvedPath);

        QStringList args;
        args << "-e" << "bash" << "-c" << cmdStr;

        QProcess *process = new QProcess(this);
        connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, name, process]() {
            process->deleteLater();
            emit editingFinished(name);
            QCoreApplication::quit();
        });
        process->start("ghostty", args);
    }
    else {
        // Para configuraciones de usuario normales
        QStringList args;
        args << "-e" << "nvim" << resolvedPath;

        QProcess *process = new QProcess(this);
        connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, name, process]() {
            // Post-editing reload logic
            if (name == "Hyprland") {
                QProcess::execute("hyprctl", QStringList() << "reload");
            } else if (name == "Waybar" || name == "Waybar Style") {
                QProcess::execute("pkill", QStringList() << "-USR2" << "waybar");
            } else if (name == "SwayNC") {
                QProcess::execute("swaync-client", QStringList() << "-R");
            }
            process->deleteLater();
            emit editingFinished(name);
            QCoreApplication::quit();
        });
        process->start("ghostty", args);
    }
}

QVariantList ConfigManager::getSystemScripts() const
{
    QVariantList list;
    QString path = QDir::homePath() + "/.config/hypr/scripts/";
    QDir dir(path);
    if (!dir.exists()) {
        return list;
    }
    
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name);
    
    QFileInfoList fileList = dir.entryInfoList();
    for (const QFileInfo &fileInfo : fileList) {
        QVariantMap map;
        map["name"] = fileInfo.fileName();
        map["path"] = fileInfo.absoluteFilePath();
        
        QString icon = ""; // Terminal script icon
        if (fileInfo.suffix() == "py") {
            icon = ""; // Python icon
        } else if (fileInfo.suffix() == "css") {
            icon = "🎨"; // CSS icon
        }
        map["icon"] = icon;
        list.append(map);
    }
    return list;
}

QVariantList ConfigManager::getQtProjects() const
{
    QVariantList list;
    QString path = QDir::homePath() + "/dotfiles/src/";
    QDir dir(path);
    if (!dir.exists()) {
        return list;
    }
    
    dir.setFilter(QDir::Dirs | QDir::NoDotAndDotDot);
    dir.setSorting(QDir::Name);
    
    QStringList dirList = dir.entryList();
    for (const QString &dirName : dirList) {
        QVariantMap map;
        map["name"] = dirName;
        map["path"] = dir.absoluteFilePath(dirName);
        map["icon"] = ""; // Folder icon
        list.append(map);
    }
    return list;
}

QVariantList ConfigManager::getProjectFiles(const QString &projectPath) const
{
    QVariantList list;
    QDir dir(projectPath);
    if (!dir.exists()) {
        return list;
    }
    
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name);
    
    QFileInfoList fileList = dir.entryInfoList();
    for (const QFileInfo &fileInfo : fileList) {
        QVariantMap map;
        map["name"] = fileInfo.fileName();
        map["path"] = fileInfo.absoluteFilePath();
        
        QString icon = ""; // Standard file icon
        if (fileInfo.suffix() == "cpp" || fileInfo.suffix() == "h") {
            icon = ""; // C++ icon
        } else if (fileInfo.suffix() == "qml") {
            icon = ""; // QML icon
        } else if (fileInfo.suffix() == "nix") {
            icon = ""; // Nix icon
        }
        map["icon"] = icon;
        list.append(map);
    }
    return list;
}
