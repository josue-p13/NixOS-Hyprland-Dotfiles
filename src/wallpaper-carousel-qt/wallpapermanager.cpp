#include "wallpapermanager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QJsonArray>
#include <QDebug>
#include <QColor>
#include <QImage>
#include <QProcess>
#include <QtConcurrent/QtConcurrent>
#include <QCoreApplication>

WallpaperManager::WallpaperManager(QObject *parent)
    : QObject(parent)
    , m_isProcessing(false)
    , m_activeCategory("All")
    , m_searchQuery("")
    , m_watcher(new QFutureWatcher<ClassificationResult>(this))
    , m_currentIndex(0)
{
    m_wallpaperDir = QDir::homePath() + "/Pictures/Wallpapers";
    m_cacheFile = QDir::homePath() + "/.cache/wallust/colors.json";
    m_metadataFile = QDir::homePath() + "/.cache/wallpaper_colors.json";
    m_favoritesFile = QDir::homePath() + "/.cache/wallpaper_favorites.json";

    // Conectar el watcher de tareas en segundo plano
    connect(m_watcher, &QFutureWatcher<ClassificationResult>::finished, this, [this]() {
        if (m_watcher->future().isValid()) {
            ClassificationResult res = m_watcher->future().result();
            if (!res.fileName.isEmpty()) {
                m_categories[res.fileName] = res.category;
                emit categoriesChanged();
            }
        }
        processNextUnclassified();
    });

    loadSystemColors();
    loadCategoriesCache();
    loadFavorites();
}

void WallpaperManager::loadWallpapers()
{
    QDir dir(m_wallpaperDir);
    if (!dir.exists()) {
        qWarning() << "El directorio de wallpapers no existe:" << m_wallpaperDir;
        return;
    }

    // Filtrar por extensiones válidas de imágenes
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp";
    dir.setNameFilters(filters);
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name);

    m_allWallpapers = dir.entryList();
    
    // Iniciar clasificación de fondos de pantalla nuevos
    startBackgroundClassification();

    applyFilter();
}

void WallpaperManager::filterByCategory(const QString &category)
{
    if (m_activeCategory != category) {
        m_activeCategory = category;
        emit categoriesChanged();
        applyFilter();
    }
}

void WallpaperManager::searchWallpapers(const QString &query)
{
    if (m_searchQuery != query) {
        m_searchQuery = query;
        applyFilter();
    }
}

void WallpaperManager::applyWallpaper(const QString &fileName)
{
    QString scriptPath = QDir::homePath() + "/dotfiles/scripts/change_wallpaper.sh";
    QString wallpaperPath = m_wallpaperDir + "/" + fileName;

    if (!QFile::exists(scriptPath)) {
        qWarning() << "No se encontró el script de cambio de wallpaper en:" << scriptPath;
        return;
    }

    // Ejecutar el script en segundo plano desvinculado
    bool started = QProcess::startDetached(scriptPath, QStringList() << wallpaperPath);
    if (started) {
        // Salir de la aplicación tras aplicar el wallpaper
        QCoreApplication::quit();
    } else {
        qWarning() << "Falló la ejecución de change_wallpaper.sh";
    }
}

void WallpaperManager::loadSystemColors()
{
    // Colores Gruvbox por defecto
    m_colors["bg"] = "#282828";
    m_colors["fg"] = "#ebdbb2";
    m_colors["accent"] = "#fe8019";
    m_colors["accent2"] = "#d3869b";
    m_colors["bg_alt"] = "#1d2021";

    QFile file(m_cacheFile);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QByteArray data = file.readAll();
        file.close();

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isNull() && doc.isObject()) {
            QJsonObject obj = doc.object();
            QJsonObject cls = obj["colors"].toObject();

            m_colors["bg"] = obj["background"].toString();
            m_colors["fg"] = obj["foreground"].toString();
            
            // Wallust mapea el color9 como el acento primario y color5 como acento secundario
            m_colors["accent"] = cls["color9"].toString();
            m_colors["accent2"] = cls["color5"].toString();
            m_colors["bg_alt"] = cls["color0"].toString();

            // Guardar toda la paleta indexada por colorX para uso dinámico
            for (auto it = cls.begin(); it != cls.end(); ++it) {
                m_colors[it.key()] = it.value().toString();
            }
        }
    }
    emit colorsChanged();
}

void WallpaperManager::loadCategoriesCache()
{
    QFile file(m_metadataFile);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QByteArray data = file.readAll();
        file.close();

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isNull() && doc.isObject()) {
            m_categories = doc.object().toVariantMap();
        }
    }
    emit categoriesChanged();
}

void WallpaperManager::saveCategoriesCache()
{
    QFile file(m_metadataFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QJsonObject obj = QJsonObject::fromVariantMap(m_categories);
        QJsonDocument doc(obj);
        file.write(doc.toJson());
        file.close();
    }
}

void WallpaperManager::loadFavorites()
{
    m_favorites.clear();
    QFile file(m_favoritesFile);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QByteArray data = file.readAll();
        file.close();

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isNull() && doc.isArray()) {
            QJsonArray arr = doc.array();
            for (const QJsonValue &val : arr) {
                m_favorites.append(val.toString());
            }
        }
    }
    emit favoritesChanged();
}

void WallpaperManager::saveFavorites()
{
    QFile file(m_favoritesFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QJsonArray arr;
        for (const QString &fav : m_favorites) {
            arr.append(fav);
        }
        QJsonDocument doc(arr);
        file.write(doc.toJson());
        file.close();
    }
}

void WallpaperManager::toggleFavorite(const QString &fileName)
{
    if (m_favorites.contains(fileName)) {
        m_favorites.removeOne(fileName);
    } else {
        m_favorites.append(fileName);
    }
    saveFavorites();
    emit favoritesChanged();
    applyFilter();
}

void WallpaperManager::applyFilter()
{
    m_wallpapers.clear();

    for (const QString &file : m_allWallpapers) {
        // Filtro de búsqueda
        if (!m_searchQuery.isEmpty() && !file.contains(m_searchQuery, Qt::CaseInsensitive)) {
            continue;
        }

        // Filtro de categoría de color
        if (m_activeCategory != "All") {
            if (m_activeCategory == "Favorites") {
                if (!m_favorites.contains(file)) {
                    continue;
                }
            } else {
                QString category = m_categories.value(file).toString();
                if (category != m_activeCategory) {
                    continue;
                }
            }
        }

        m_wallpapers.append(file);
    }

    emit wallpapersChanged();
}

void WallpaperManager::startBackgroundClassification()
{
    m_unclassifiedFiles.clear();
    for (const QString &file : m_allWallpapers) {
        if (!m_categories.contains(file)) {
            m_unclassifiedFiles.append(file);
        }
    }

    if (m_unclassifiedFiles.isEmpty()) {
        return;
    }

    m_isProcessing = true;
    emit isProcessingChanged();
    m_currentIndex = 0;

    processNextUnclassified();
}

void WallpaperManager::processNextUnclassified()
{
    if (m_currentIndex >= m_unclassifiedFiles.size()) {
        saveCategoriesCache();
        m_isProcessing = false;
        emit isProcessingChanged();
        applyFilter();
        return;
    }

    QString fileToClassify = m_unclassifiedFiles[m_currentIndex];
    m_currentIndex++;

    // Lanzar el hilo con QtConcurrent para procesar la imagen en segundo plano
    QFuture<ClassificationResult> future = QtConcurrent::run(classifyImageJob, m_wallpaperDir, fileToClassify);
    m_watcher->setFuture(future);
}

// Algoritmo de clasificación de color dominante en C++
WallpaperManager::ClassificationResult WallpaperManager::classifyImageJob(const QString &dir, const QString &fileName)
{
    ClassificationResult result;
    result.fileName = fileName;
    result.category = "All";

    QString fullPath = dir + "/" + fileName;
    QImage img;
    if (!img.load(fullPath)) {
        return result;
    }

    // Escalar la imagen a un tamaño pequeño para muestrear píxeles ultra rápido (ej. 80x80)
    QImage thumb = img.scaled(80, 80, Qt::KeepAspectRatio, Qt::FastTransformation);
    int width = thumb.width();
    int height = thumb.height();

    // Contadores de categorías de color (Hue en grados)
    QMap<QString, double> hScores;
    hScores["Red"] = 0;
    hScores["Orange"] = 0;
    hScores["Yellow"] = 0;
    hScores["Green"] = 0;
    hScores["Blue"] = 0;
    hScores["Purple"] = 0;
    hScores["Pink"] = 0;

    int darkCount = 0;
    int sampleSize = 0;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            QColor color = thumb.pixelColor(x, y);
            sampleSize++;

            double h = color.hueF() * 360.0;
            double s = color.saturationF();
            double v = color.valueF();

            // Clasificación de brillo/saturación (igual a la lógica Python)
            if (v < 0.2 || (s < 0.2 && v < 0.5)) {
                darkCount++;
                continue;
            }

            if (s > 0.3) {
                double weight = s * v;

                // Mapeo de rangos de color (Hue en grados 0-360)
                if ((h >= 0 && h <= 15) || (h >= 345 && h <= 360)) {
                    hScores["Red"] += weight;
                } else if (h > 15 && h <= 45) {
                    hScores["Orange"] += weight;
                } else if (h > 45 && h <= 70) {
                    hScores["Yellow"] += weight;
                } else if (h > 70 && h <= 165) {
                    hScores["Green"] += weight;
                } else if (h > 165 && h <= 255) {
                    hScores["Blue"] += weight;
                } else if (h > 255 && h <= 300) {
                    hScores["Purple"] += weight;
                } else if (h > 300 && h < 345) {
                    hScores["Pink"] += weight;
                }
            }
        }
    }

    // Si más del 60% de los píxeles son oscuros, clasificar como Dark
    if (darkCount > (sampleSize * 0.6)) {
        result.category = "Dark";
        return result;
    }

    // Determinar qué categoría tiene la puntuación más alta
    QString bestCategory = "All";
    double maxScore = 0;
    for (auto it = hScores.constBegin(); it != hScores.constEnd(); ++it) {
        if (it.value() > maxScore) {
            maxScore = it.value();
            bestCategory = it.key();
        }
    }

    if (maxScore == 0) {
        result.category = (darkCount > (sampleSize * 0.3)) ? "Dark" : "All";
    } else {
        result.category = bestCategory;
    }

    return result;
}
