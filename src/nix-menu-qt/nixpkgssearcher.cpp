#include "nixpkgssearcher.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QRegularExpression>
#include <QFileInfo>
#include <QDateTime>
#include <QtConcurrent>
#include <QDebug>

NixpkgsSearcher::NixpkgsSearcher(QObject *parent)
    : QObject(parent)
    , m_isLoading(false)
{
    m_cachePath = QDir::homePath() + "/.cache/nix-menu-qt/nixpkgs-names.txt";

    // Inicializar lista popular para que la UX sea instantánea desde el primer segundo
    m_popularPackages = QStringList({
        "firefox", "brave", "google-chrome", "chromium",
        "vscode", "neovim", "vim", "helix", "zed-editor", "sublime-text",
        "ghostty", "warp-terminal", "kitty", "alacritty", "wezterm",
        "git", "gh", "git-lfs", "lazygit",
        "docker", "docker-compose", "podman",
        "spotify", "mpv", "vlc", "ffmpeg", "obs-studio", "cava",
        "discord", "telegram-desktop", "slack", "zoom-us",
        "nautilus", "thunar", "dolphin",
        "btop", "htop", "fastfetch", "eza", "bat", "fzf", "ripgrep", "fd", "jq",
        "python3", "nodejs", "bun", "pnpm", "yarn", "rustc", "cargo", "go", "gcc", "cmake",
        "ollama", "ollama-cuda", "cudatoolkit",
        "libreoffice", "onlyoffice-desktopeditors", "obsidian",
        "steam", "prismlauncher", "lutris",
        "waybar", "swaynotificationcenter", "hyprpaper", "wallust", "grimblast", "wl-clipboard", "cliphist"
    });

    loadCacheAsync();
}

QStringList NixpkgsSearcher::packages() const
{
    return m_packages.isEmpty() ? m_popularPackages : m_packages;
}

bool NixpkgsSearcher::isLoading() const
{
    return m_isLoading;
}

void NixpkgsSearcher::loadCacheAsync()
{
    m_isLoading = true;
    emit isLoadingChanged();

    QtConcurrent::run([this]() {
        QFile file(m_cachePath);
        bool cacheExists = file.exists();
        bool needRebuild = !cacheExists;

        if (cacheExists) {
            // Comprobar si el caché tiene más de 7 días
            QFileInfo info(file);
            if (info.lastModified().daysTo(QDateTime::currentDateTime()) > 7) {
                needRebuild = true;
            }

            // Cargar caché actual mientras se decide si reconstruir
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&file);
                QStringList cached;
                while (!in.atEnd()) {
                    QString line = in.readLine().trimmed();
                    if (!line.isEmpty()) {
                        cached.append(line);
                    }
                }
                file.close();
                
                if (!cached.isEmpty()) {
                    m_packages = cached;
                    m_isLoading = false;
                    emit packagesChanged();
                    emit isLoadingChanged();
                    
                    if (!needRebuild) {
                        return; // No requiere reconstrucción, terminar
                    }
                }
            }
        }

        // Reconstruir el caché de paquetes
        m_isLoading = true;
        emit isLoadingChanged();

        QProcess proc;
        proc.start("nix-env", QStringList() << "-qaP");
        if (proc.waitForFinished(90000)) { // 90 segundos máx
            QString output = proc.readAllStandardOutput();
            QStringList lines = output.split('\n');
            QStringList cleaned;
            cleaned.reserve(lines.size());

            for (const QString &line : lines) {
                QStringList parts = line.split(QRegularExpression("\\s+"));
                if (parts.size() >= 1) {
                    QString attr = parts[0];
                    if (attr.startsWith("nixos.")) {
                        attr = attr.mid(6);
                    } else if (attr.startsWith("nixpkgs.")) {
                        attr = attr.mid(8);
                    }
                    if (!attr.isEmpty() && !cleaned.contains(attr)) {
                        cleaned.append(attr);
                    }
                }
            }

            if (!cleaned.isEmpty()) {
                // Guardar en archivo caché
                QDir().mkpath(QFileInfo(m_cachePath).absolutePath());
                if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                    QTextStream out(&file);
                    for (const QString &attr : cleaned) {
                        out << attr << "\n";
                    }
                    file.close();
                }
                m_packages = cleaned;
            }
        }

        m_isLoading = false;
        emit packagesChanged();
        emit isLoadingChanged();
    });
}

QStringList NixpkgsSearcher::search(const QString &query)
{
    if (query.isEmpty()) {
        return packages();
    }

    QStringList sourceList = m_packages.isEmpty() ? m_popularPackages : m_packages;
    QStringList results;
    int count = 0;

    for (const QString &pkg : sourceList) {
        if (pkg.contains(query, Qt::CaseInsensitive)) {
            results.append(pkg);
            count++;
            if (count >= 100) { // Limitar a los mejores 100 resultados para no ralentizar la GUI
                break;
            }
        }
    }
    return results;
}

void NixpkgsSearcher::runTemp(const QString &packageName)
{
    QStringList args;
    args << "-e" << "nix-shell" << "-p" << packageName;
    QProcess::startDetached("ghostty", args);
}

void NixpkgsSearcher::installPermanent(const QString &packageName)
{
    // Comando en Python de una sola línea para insertar de manera segura el paquete en la configuración
    QString pyCmd = QString(
        "import sys; "
        "path = '/etc/nixos/configuration.nix'; "
        "f = open(path, 'r'); c = f.read(); f.close(); "
        "target = 'environment.systemPackages = with pkgs; ['; "
        "if target in c: "
        "    c = c.replace(target, target + '\\\\n    ' + sys.argv[1]); "
        "f = open(path, 'w'); f.write(c); f.close();"
    );

    // Concatenar comandos Bash para ejecutar la edición con sudo y luego realizar nixos-rebuild
    QString cmdStr = QString(
        "sudo python3 -c \"%1\" %2 && "
        "cd /etc/nixos && sudo git add . && "
        "sudo nixos-rebuild switch --flake .#nixos; "
        "echo ''; echo 'Instalación de %2 completada. Presiona Enter para cerrar...'; read"
    ).arg(pyCmd).arg(packageName);

    QStringList args;
    args << "-e" << "bash" << "-c" << cmdStr;
    QProcess::startDetached("ghostty", args);
}
