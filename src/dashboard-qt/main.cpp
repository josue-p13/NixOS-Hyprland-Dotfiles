#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <LayerShellQt/Shell>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>
#include "systemmonitor.h"
#include "spotifyplayer.h"
#include "thememanager.h"
#include "dashboardmanager.h"
#include "equalizermanager.h"
#include "monitormanager.h"
#include "wifimanager.h"
#include "bluetoothmanager.h"
#include "audiomanager.h"
#include "mixermanager.h"

int main(int argc, char *argv[])
{
    // Enable Wayland Layer Shell support in Qt
    LayerShellQt::Shell::useLayerShell();

    // Enable Wayland integration if possible
    qputenv("QT_QPA_PLATFORM", "wayland;xcb");

    QGuiApplication app(argc, argv);

    // Set application name and desktop name for Hyprland window rules
    QGuiApplication::setApplicationName("dashboard-qt");
    QGuiApplication::setDesktopFileName("dashboard-qt");

    // Instantiate backend classes
    SystemMonitor monitor;
    SpotifyPlayer spotify;
    ThemeManager theme;
    DashboardManager dashboard;
    EqualizerManager equalizer;
    MonitorManager monitorManager;
    WifiManager wifiManager;
    BluetoothManager bluetoothManager;
    AudioManager audioManager;
    MixerManager mixerManager;

    // Register DashboardManager on D-Bus
    QDBusConnection connection = QDBusConnection::sessionBus();
    if (!connection.registerService("org.josue.dashboard")) {
        qWarning() << "Failed to register D-Bus service org.josue.dashboard:" << connection.lastError().message();
    }
    if (!connection.registerObject("/org/josue/dashboard", &dashboard, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties)) {
        qWarning() << "Failed to register D-Bus object /org/josue/dashboard:" << connection.lastError().message();
    }

    // Register MonitorManager on D-Bus
    if (!connection.registerService("org.josue.monitor")) {
        qWarning() << "Failed to register D-Bus service org.josue.monitor:" << connection.lastError().message();
    }
    if (!connection.registerObject("/org/josue/monitor", &monitorManager, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties)) {
        qWarning() << "Failed to register D-Bus object /org/josue/monitor:" << connection.lastError().message();
    }

    // Register WifiManager on D-Bus
    if (!connection.registerService("org.josue.wifi")) {
        qWarning() << "Failed to register D-Bus service org.josue.wifi:" << connection.lastError().message();
    }
    if (!connection.registerObject("/org/josue/wifi", &wifiManager, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties)) {
        qWarning() << "Failed to register D-Bus object /org/josue/wifi:" << connection.lastError().message();
    }

    // Register BluetoothManager on D-Bus
    if (!connection.registerService("org.josue.bluetooth")) {
        qWarning() << "Failed to register D-Bus service org.josue.bluetooth:" << connection.lastError().message();
    }
    if (!connection.registerObject("/org/josue/bluetooth", &bluetoothManager, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties)) {
        qWarning() << "Failed to register D-Bus object /org/josue/bluetooth:" << connection.lastError().message();
    }

    // Register AudioManager on D-Bus
    if (!connection.registerService("org.josue.audio")) {
        qWarning() << "Failed to register D-Bus service org.josue.audio:" << connection.lastError().message();
    }
    if (!connection.registerObject("/org/josue/audio", &audioManager, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties)) {
        qWarning() << "Failed to register D-Bus object /org/josue/audio:" << connection.lastError().message();
    }

    // Register MixerManager on D-Bus
    if (!connection.registerService("org.josue.mixer")) {
        qWarning() << "Failed to register D-Bus service org.josue.mixer:" << connection.lastError().message();
    }
    if (!connection.registerObject("/org/josue/mixer", &mixerManager, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties)) {
        qWarning() << "Failed to register D-Bus object /org/josue/mixer:" << connection.lastError().message();
    }

    QQmlApplicationEngine engine;

    // Register controllers in QML context
    engine.rootContext()->setContextProperty("systemMonitor", &monitor);
    engine.rootContext()->setContextProperty("spotifyPlayer", &spotify);
    engine.rootContext()->setContextProperty("themeManager", &theme);
    engine.rootContext()->setContextProperty("dashboardManager", &dashboard);
    engine.rootContext()->setContextProperty("equalizerManager", &equalizer);
    engine.rootContext()->setContextProperty("monitorManager", &monitorManager);
    engine.rootContext()->setContextProperty("wifiManager", &wifiManager);
    engine.rootContext()->setContextProperty("bluetoothManager", &bluetoothManager);
    engine.rootContext()->setContextProperty("audioManager", &audioManager);
    engine.rootContext()->setContextProperty("mixerManager", &mixerManager);

    // Connect failure handler
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    // Load QML files from compiled Qt resources
    const QUrl url(QStringLiteral("qrc:/qt/qml/Dashboard/main.qml"));
    engine.load(url);

    const QUrl monitorUrl(QStringLiteral("qrc:/qt/qml/Dashboard/MonitorWindow.qml"));
    engine.load(monitorUrl);

    const QUrl wifiUrl(QStringLiteral("qrc:/qt/qml/Dashboard/WifiWindow.qml"));
    engine.load(wifiUrl);

    const QUrl bluetoothUrl(QStringLiteral("qrc:/qt/qml/Dashboard/BluetoothWindow.qml"));
    engine.load(bluetoothUrl);

    const QUrl audioUrl(QStringLiteral("qrc:/qt/qml/Dashboard/AudioWindow.qml"));
    engine.load(audioUrl);

    const QUrl mixerUrl(QStringLiteral("qrc:/qt/qml/Dashboard/MixerWindow.qml"));
    engine.load(mixerUrl);

    return app.exec();
}

