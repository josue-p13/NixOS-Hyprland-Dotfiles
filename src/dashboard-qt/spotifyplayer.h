#ifndef SPOTIFYPLAYER_H
#define SPOTIFYPLAYER_H

#include <QObject>
#include <QVariantMap>
#include <QDBusConnection>
#include <QDBusMessage>

class SpotifyPlayer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasMusic READ hasMusic NOTIFY hasMusicChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(QString title READ title NOTIFY metadataChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY metadataChanged)
    Q_PROPERTY(QString albumArt READ albumArt NOTIFY metadataChanged)

public:
    explicit SpotifyPlayer(QObject *parent = nullptr);

    bool hasMusic() const { return m_hasMusic; }
    bool isPlaying() const { return m_isPlaying; }
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString albumArt() const { return m_albumArt; }

public slots:
    void playPause();
    void next();
    void previous();

signals:
    void hasMusicChanged();
    void isPlayingChanged();
    void metadataChanged();

private slots:
    void onServiceOwnerChanged(const QString &serviceName, const QString &oldOwner, const QString &newOwner);
    void onPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties);

private:
    void checkService();
    void reEvaluatePlayers();
    void setActiveService(const QString &service);
    void fetchProperties();
    void updateMetadata(const QVariantMap &metadata);
    void updatePlaybackStatus(const QString &status);

    bool m_hasMusic = false;
    bool m_isPlaying = false;
    QString m_title = "Sin música";
    QString m_artist = "Inicia un reproductor";
    QString m_albumArt = "";

    QString m_serviceName = "";
    const QString m_objectPath = "/org/mpris/MediaPlayer2";
    const QString m_interfaceName = "org.mpris.MediaPlayer2.Player";
};

#endif // SPOTIFYPLAYER_H
