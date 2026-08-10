cmake_minimum_required(VERSION 3.16)
project(dashboard-qt VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find needed Qt6 components
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Concurrent DBus)
find_package(LayerShellQt REQUIRED)

# Set Qt QML resource prefix policy
qt_policy(SET QTP0001 NEW)

qt_standard_project_setup()

# Define executable and sources
qt_add_executable(dashboard-qt
    main.cpp
    systemmonitor.h
    systemmonitor.cpp
    spotifyplayer.h
    spotifyplayer.cpp
    thememanager.h
    thememanager.cpp
    dashboardmanager.h
    dashboardmanager.cpp
    equalizermanager.h
    equalizermanager.cpp
    monitormanager.h
    monitormanager.cpp
    wifimanager.h
    wifimanager.cpp
    bluetoothmanager.h
    bluetoothmanager.cpp
    audiomanager.h
    audiomanager.cpp
    mixermanager.h
    mixermanager.cpp
)

# Register the QML module and embed main.qml
qt_add_qml_module(dashboard-qt
    URI Dashboard
    VERSION 1.0
    QML_FILES
        main.qml
        MonitorWindow.qml
        WifiWindow.qml
        BluetoothWindow.qml
        AudioWindow.qml
        MixerWindow.qml
)

# Link Qt libraries
target_link_libraries(dashboard-qt PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Concurrent
    Qt6::DBus
    LayerShellQt::Interface
)

# Install rule for nix-build packaging
install(TARGETS dashboard-qt RUNTIME DESTINATION bin)
