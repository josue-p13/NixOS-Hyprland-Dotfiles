#include "spotifyplayer.h"
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusConnectionInterface>
#include <QVariantMap>
#include <QStringList>
#include <QDebug>
#include <QDBusArgument>

// Helper to unpack QDBusArgument to QVariantMap
static QVariantMap unpackMetadata(const QVariant &var)
{
    if (var.canConvert<QVariantMap>()) {
        return var.toMap();
    }
    return qdbus_cast<QVariantMap>(var);
}

SpotifyPlayer::SpotifyPlayer(QObject *parent)
    : QObject(parent)
{
    // Connect to NameOwnerChanged on the DBus Daemon to listen to MPRIS players starting/stopping
    QDBusConnection::sessionBus().connect(
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "NameOwnerChanged",
        this,
        SLOT(onServiceOwnerChanged(QString,QString,QString))
    );

    // Initial check to find active player
    checkService();
}

void SpotifyPlayer::checkService()
{
    reEvaluatePlayers();
}

void SpotifyPlayer::reEvaluatePlayers()
{
    QDBusConnectionInterface *connInterface = QDBusConnection::sessionBus().interface();
    if (!connInterface)
        return;

    QDBusReply<QStringList> reply = connInterface->registeredServiceNames();
    if (!reply.isValid())
        return;

    QStringList services = reply.value();
    QStringList mprisServices;
    for (const QString &service : services) {
        if (service.startsWith("org.mpris.MediaPlayer2.")) {
            mprisServices.append(service);
        }
    }

    if (mprisServices.isEmpty()) {
        setActiveService("");
        return;
    }

    // Selection logic:
    // 1. If any player is currently "Playing", choose it immediately.
    // 2. If no player is playing, but there is "org.mpris.MediaPlayer2.spotify", choose it.
    // 3. If there is a player that is not a proxy (e.g. not playerctld), choose the first one.
    // 4. Fall back to the first available player.

    QString bestService = "";

    // Pass 1: Look for any active playing player
    for (const QString &service : mprisServices) {
        QDBusInterface dbusInterface(service, m_objectPath, "org.freedesktop.DBus.Properties", QDBusConnection::sessionBus());
        if (dbusInterface.isValid()) {
            QDBusReply<QVariant> statusReply = dbusInterface.call("Get", m_interfaceName, "PlaybackStatus");
            if (statusReply.isValid() && statusReply.value().toString().toLower() == "playing") {
                bestService = service;
                break;
            }
        }
    }

    // Pass 2: Look for Spotify (prefer desktop app even if paused)
    if (bestService.isEmpty()) {
        for (const QString &service : mprisServices) {
            if (service.contains("spotify")) {
                bestService = service;
                break;
            }
        }
    }

    // Pass 3: Look for any other player (excluding playerctld proxy)
    if (bestService.isEmpty()) {
        for (const QString &service : mprisServices) {
            if (service != "org.mpris.MediaPlayer2.playerctld") {
                bestService = service;
                break;
            }
        }
    }

    // Pass 4: Fall back to first one
    if (bestService.isEmpty() && !mprisServices.isEmpty()) {
        bestService = mprisServices.first();
    }

    setActiveService(bestService);
}

void SpotifyPlayer::setActiveService(const QString &service)
{
    if (m_serviceName == service && m_hasMusic) {
        return;
    }

    if (!m_serviceName.isEmpty()) {
        QDBusConnection::sessionBus().disconnect(
            m_serviceName,
            m_objectPath,
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            this,
            SLOT(onPropertiesChanged(QString,QVariantMap,QStringList))
        );
    }

    m_serviceName = service;

    if (!m_serviceName.isEmpty()) {
        QDBusConnection::sessionBus().connect(
            m_serviceName,
            m_objectPath,
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            this,
            SLOT(onPropertiesChanged(QString,QVariantMap,QStringList))
        );
        m_hasMusic = true;
        emit hasMusicChanged();
        fetchProperties();
    } else {
        m_hasMusic = false;
        m_isPlaying = false;
        m_title = "Sin música";
        m_artist = "Inicia un reproductor";
        m_albumArt = "";
        emit hasMusicChanged();
        emit isPlayingChanged();
        emit metadataChanged();
    }
}

void SpotifyPlayer::fetchProperties()
{
    if (m_serviceName.isEmpty())
        return;

    QDBusInterface dbusInterface(m_serviceName, m_objectPath, "org.freedesktop.DBus.Properties", QDBusConnection::sessionBus());
    if (!dbusInterface.isValid())
        return;

    QDBusReply<QVariantMap> reply = dbusInterface.call("GetAll", m_interfaceName);
    if (reply.isValid()) {
        QVariantMap props = reply.value();
        updatePlaybackStatus(props.value("PlaybackStatus").toString());
        updateMetadata(unpackMetadata(props.value("Metadata")));
    }
}

void SpotifyPlayer::onServiceOwnerChanged(const QString &serviceName, const QString &oldOwner, const QString &newOwner)
{
    if (serviceName.startsWith("org.mpris.MediaPlayer2.")) {
        Q_UNUSED(oldOwner);
        Q_UNUSED(newOwner);
        reEvaluatePlayers();
    }
}

void SpotifyPlayer::onPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties)
{
    Q_UNUSED(invalidatedProperties);

    if (interfaceName == m_interfaceName) {
        if (changedProperties.contains("PlaybackStatus")) {
            updatePlaybackStatus(changedProperties.value("PlaybackStatus").toString());
        }
        if (changedProperties.contains("Metadata")) {
            updateMetadata(unpackMetadata(changedProperties.value("Metadata")));
        }
    }
}

void SpotifyPlayer::updatePlaybackStatus(const QString &status)
{
    bool playing = (status.toLower() == "playing");
    if (m_isPlaying != playing) {
        m_isPlaying = playing;
        emit isPlayingChanged();
    }
}

void SpotifyPlayer::updateMetadata(const QVariantMap &metadata)
{
    QString newTitle = metadata.value("xesam:title").toString();
    
    QVariant artistVar = metadata.value("xesam:artist");
    QString newArtist;
    if (artistVar.canConvert<QStringList>()) {
        newArtist = artistVar.toStringList().join(", ");
    } else {
        newArtist = artistVar.toString();
    }

    QString newArt = metadata.value("mpris:artUrl").toString();

    // Fallbacks if title or artist are empty
    if (newTitle.isEmpty()) {
        newTitle = "Desconocido";
    }
    if (newArtist.isEmpty()) {
        newArtist = "Artista Desconocido";
    }

    if (m_title != newTitle || m_artist != newArtist || m_albumArt != newArt) {
        m_title = newTitle;
        m_artist = newArtist;
        m_albumArt = newArt;
        emit metadataChanged();
    }
}

void SpotifyPlayer::playPause()
{
    if (m_serviceName.isEmpty()) return;
    QDBusInterface dbusInterface(m_serviceName, m_objectPath, m_interfaceName, QDBusConnection::sessionBus());
    if (dbusInterface.isValid()) {
        dbusInterface.call("PlayPause");
    }
}

void SpotifyPlayer::next()
{
    if (m_serviceName.isEmpty()) return;
    QDBusInterface dbusInterface(m_serviceName, m_objectPath, m_interfaceName, QDBusConnection::sessionBus());
    if (dbusInterface.isValid()) {
        dbusInterface.call("Next");
    }
}

void SpotifyPlayer::previous()
{
    if (m_serviceName.isEmpty()) return;
    QDBusInterface dbusInterface(m_serviceName, m_objectPath, m_interfaceName, QDBusConnection::sessionBus());
    if (dbusInterface.isValid()) {
        dbusInterface.call("Previous");
    }
}
