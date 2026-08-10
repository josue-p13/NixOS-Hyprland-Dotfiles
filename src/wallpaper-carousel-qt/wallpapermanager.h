#ifndef WALLPAPERMANAGER_H
#define WALLPAPERMANAGER_H

#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFutureWatcher>

class WallpaperManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList wallpapers READ wallpapers NOTIFY wallpapersChanged)
    Q_PROPERTY(QVariantMap colors READ colors NOTIFY colorsChanged)
    Q_PROPERTY(QVariantMap categories READ categories NOTIFY categoriesChanged)
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    Q_PROPERTY(QString wallpaperDir READ wallpaperDir CONSTANT)
    Q_PROPERTY(QStringList favorites READ favorites NOTIFY favoritesChanged)

public:
    explicit WallpaperManager(QObject *parent = nullptr);

    QStringList wallpapers() const { return m_wallpapers; }
    QVariantMap colors() const { return m_colors; }
    QVariantMap categories() const { return m_categories; }
    bool isProcessing() const { return m_isProcessing; }
    QString wallpaperDir() const { return m_wallpaperDir; }
    QStringList favorites() const { return m_favorites; }

    Q_INVOKABLE void loadWallpapers();
    Q_INVOKABLE void filterByCategory(const QString &category);
    Q_INVOKABLE void searchWallpapers(const QString &query);
    Q_INVOKABLE void applyWallpaper(const QString &fileName);
    Q_INVOKABLE void toggleFavorite(const QString &fileName);

signals:
    void wallpapersChanged();
    void colorsChanged();
    void categoriesChanged();
    void isProcessingChanged();
    void favoritesChanged();

private:
    void loadSystemColors();
    void loadCategoriesCache();
    void saveCategoriesCache();
    void loadFavorites();
    void saveFavorites();
    void startBackgroundClassification();
    void applyFilter();

    // Struct para clasificar imágenes en hilos secundarios
    struct ClassificationResult {
        QString fileName;
        QString category;
    };
    
    static ClassificationResult classifyImageJob(const QString &dir, const QString &fileName);

    QStringList m_allWallpapers;
    QStringList m_wallpapers;
    QVariantMap m_colors;
    QVariantMap m_categories; // Mapeo de fileName -> categoría de color
    QStringList m_favorites;
    bool m_isProcessing;

    QString m_wallpaperDir;
    QString m_cacheFile;
    QString m_metadataFile;
    QString m_favoritesFile;
    QString m_activeCategory;
    QString m_searchQuery;

    QFutureWatcher<ClassificationResult> *m_watcher;
    QStringList m_unclassifiedFiles;
    int m_currentIndex;

    void processNextUnclassified();
};

#endif // WALLPAPERMANAGER_H
