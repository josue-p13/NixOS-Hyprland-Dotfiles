#include "pwamanager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QUrl>

PwaManager::PwaManager(QObject *parent)
    : QObject(parent)
{
}

bool PwaManager::createPwa(const QString &name, const QString &url, const QString &iconPath)
{
    if (name.isEmpty() || url.isEmpty()) {
        return false;
    }

    // Sanitizar el nombre para el nombre de archivo y la clase de ventana
    QString sanitized = name.trimmed().toLower();
    sanitized.replace(QRegularExpression("[^a-z0-9]"), "-");
    while (sanitized.contains("--")) {
        sanitized.replace("--", "-");
    }

    QString dirPath = QDir::homePath() + "/.local/share/applications/";
    QDir().mkpath(dirPath); // Asegurar que el directorio de aplicaciones existe

    QString fileName = QString("brave-pwa-%1.desktop").arg(sanitized);
    QString fullPath = dirPath + fileName;

    QFile file(fullPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    // Resolver la ruta del icono (eliminar prefijo file:// de QML)
    QString resolvedIcon = iconPath;
    if (resolvedIcon.startsWith("file://")) {
        resolvedIcon = QUrl(resolvedIcon).toLocalFile();
    }

    QTextStream out(&file);
    out << "[Desktop Entry]\n";
    out << "Version=1.0\n";
    out << "Name=" << name << "\n";
    out << "Comment=Launch " << name << " Web App\n";
    out << "Exec=brave --app=" << url << " --class=brave-pwa-" << sanitized << "\n";
    if (!resolvedIcon.isEmpty()) {
        out << "Icon=" << resolvedIcon << "\n";
    } else {
        out << "Icon=brave\n"; // Fallback al icono de Brave
    }
    out << "Terminal=false\n";
    out << "Type=Application\n";
    out << "StartupWMClass=brave-pwa-" << sanitized << "\n";
    out << "Categories=Network;WebBrowser;\n";
    file.close();

    return true;
}
