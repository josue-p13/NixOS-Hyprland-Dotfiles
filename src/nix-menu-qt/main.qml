import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtCore

Window {
    id: root
    visible: true
    width: Screen.width
    height: Screen.height
    color: "transparent"
    title: "Nix Menu"
    flags: Qt.FramelessWindowHint | Qt.Window

    // Colores dinámicos del gestor de temas
    property var colors: themeManager.colors
    property color bg: colors.background ? colors.background : "#2B2B2B"
    property color fg: colors.foreground ? colors.foreground : "#FDECE0"
    property color accent: (colors.colors && colors.colors.color9) ? colors.colors.color9 : "#fe8019"
    property color highlightColor: (colors.colors && colors.colors.color3) ? colors.colors.color3 : "#91B0C4"
    property color cardBg: (colors.colors && colors.colors.color8) ? colors.colors.color8 : "#3c3836"

    // 0: Menú Principal, 1: Nixpkgs, 2: PWA, 3: Menu Configs, 4: Scripts, 5: Proyectos Qt, 6: Archivos de Proyecto
    property int currentView: 0 
    property string selectedProjectPath: ""
    property string selectedProjectName: ""

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.currentView === 1 || root.currentView === 2 || root.currentView === 3) {
                    root.currentView = 0;
                    mainMenuListView.focus = true;
                } else if (root.currentView === 4 || root.currentView === 5) {
                    root.currentView = 3;
                    configsListView.focus = true;
                } else if (root.currentView === 6) {
                    root.currentView = 5;
                    projectsListView.focus = true;
                } else {
                    Qt.quit();
                }
                event.accepted = true;
            }
        }

        // Fondo translúcido
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.45

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }
        }

        // Panel Principal Centrado
        Rectangle {
            id: mainPanel
            width: 480
            height: 480
            anchors.centerIn: parent
            color: root.bg
            radius: 12
            border.color: root.accent
            border.width: 1
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            // ================= VIEW 0: MENU DE INICIO (3 OPCIONES EXACTAS) =================
            Item {
                id: mainMenuView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 0

                onVisibleChanged: {
                    if (visible) {
                        mainMenuListView.focus = true;
                    }
                }

                Text {
                    id: menuTitle
                    text: "  NIX MENU"
                    color: root.accent
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 14
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                ListView {
                    id: mainMenuListView
                    anchors.top: menuTitle.bottom
                    anchors.topMargin: 25
                    anchors.bottom: parent.bottom
                    width: parent.width
                    focus: true
                    clip: true
                    spacing: 8

                    model: ListModel {
                        id: menuModel
                        ListElement { name: "Configuraciones del Sistema"; icon: ""; targetView: 3 }
                        ListElement { name: "Buscar e Instalar Paquetes"; icon: ""; targetView: 1 }
                        ListElement { name: "Crear Web App (PWA)"; icon: "󰖟"; targetView: 2 }
                    }

                    delegate: Rectangle {
                        width: mainMenuListView.width
                        height: 45
                        color: ListView.isCurrentItem ? root.cardBg : "transparent"
                        radius: 6
                        border.color: ListView.isCurrentItem ? root.accent : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            spacing: 15

                            Text {
                                text: model.icon
                                color: ListView.isCurrentItem ? root.accent : root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: model.name
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 14
                                font.bold: ListView.isCurrentItem
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: mainMenuListView.currentIndex = index
                            onClicked: root.currentView = model.targetView
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.currentView = menuModel.get(currentIndex).targetView;
                            event.accepted = true;
                        }
                    }
                }
            }

            // ================= VIEW 3: CONFIGURACIONES (SUBMENÚ DETALLADO) =================
            Item {
                id: configsView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 3

                onVisibleChanged: {
                    if (visible) {
                        configsListView.focus = true;
                    }
                }

                Text {
                    id: configsTitle
                    text: "  CONFIGURACIONES DEL SISTEMA"
                    color: root.accent
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 13
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                ListView {
                    id: configsListView
                    anchors.top: configsTitle.bottom
                    anchors.topMargin: 15
                    anchors.bottom: backButtonConfigs.top
                    anchors.bottomMargin: 10
                    width: parent.width
                    clip: true
                    spacing: 4

                    model: ListModel {
                        id: configListModel
                        // Estáticos
                        ListElement { name: "NixOS Config"; icon: ""; type: "static"; path: "/etc/nixos/configuration.nix" }
                        ListElement { name: "NixOS Flake"; icon: ""; type: "static"; path: "/etc/nixos/flake.nix" }
                        ListElement { name: "Hyprland Config"; icon: ""; type: "static"; path: "~/.config/hypr/hyprland.conf" }
                        ListElement { name: "Waybar Config"; icon: ""; type: "static"; path: "~/.config/waybar/config" }
                        ListElement { name: "Waybar Style"; icon: "󰏘"; type: "static"; path: "~/.config/waybar/style.css" }
                        ListElement { name: "SwayNC Config"; icon: ""; type: "static"; path: "~/.config/swaync/config.json" }
                        ListElement { name: "Ghostty Config"; icon: ""; type: "static"; path: "~/.config/ghostty/config" }
                        // Dinámicos
                        ListElement { name: "Scripts del Sistema"; icon: ""; type: "view"; path: "4" }
                        ListElement { name: "Proyectos Qt/C++"; icon: ""; type: "view"; path: "5" }
                    }

                    delegate: Rectangle {
                        width: configsListView.width
                        height: 34
                        color: ListView.isCurrentItem ? root.cardBg : "transparent"
                        radius: 6
                        border.color: ListView.isCurrentItem ? root.accent : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12

                            Text {
                                text: model.icon
                                color: ListView.isCurrentItem ? root.accent : root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: model.name
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: configsListView.currentIndex = index
                            onClicked: triggerConfigAction(model.type, model.name, model.path)
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            var item = configListModel.get(currentIndex);
                            triggerConfigAction(item.type, item.name, item.path);
                            event.accepted = true;
                        }
                    }
                }

                Button {
                    id: backButtonConfigs
                    text: "  Volver"
                    flat: true
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    anchors.bottom: parent.bottom
                    contentItem: Text { text: parent.text; font: parent.font; color: root.accent }
                    onClicked: {
                        root.currentView = 0;
                        mainMenuListView.focus = true;
                    }
                }
            }

            // ================= VIEW 4: SCRIPTS DINÁMICOS =================
            Item {
                id: scriptsView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 4

                onVisibleChanged: {
                    if (visible) {
                        scriptsListView.model = configManager.getSystemScripts();
                        scriptsListView.focus = true;
                    }
                }

                Text {
                    id: scriptsTitle
                    text: "  SCRIPTS DEL SISTEMA (~/.config/hypr/scripts)"
                    color: root.accent
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 12
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                ListView {
                    id: scriptsListView
                    anchors.top: scriptsTitle.bottom
                    anchors.topMargin: 15
                    anchors.bottom: backButtonScripts.top
                    anchors.bottomMargin: 10
                    width: parent.width
                    clip: true
                    spacing: 4

                    delegate: Rectangle {
                        width: scriptsListView.width
                        height: 34
                        color: ListView.isCurrentItem ? root.cardBg : "transparent"
                        radius: 6
                        border.color: ListView.isCurrentItem ? root.accent : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12

                            Text {
                                text: modelData.icon
                                color: ListView.isCurrentItem ? root.accent : root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.name
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: scriptsListView.currentIndex = index
                            onClicked: {
                                configManager.editConfig(modelData.name, modelData.path);
                                root.visible = false;
                            }
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (count > 0 && currentIndex >= 0) {
                                var script = model[currentIndex];
                                configManager.editConfig(script.name, script.path);
                                root.visible = false;
                            }
                            event.accepted = true;
                        }
                    }
                }

                Button {
                    id: backButtonScripts
                    text: "  Volver"
                    flat: true
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    anchors.bottom: parent.bottom
                    contentItem: Text { text: parent.text; font: parent.font; color: root.accent }
                    onClicked: {
                        root.currentView = 3;
                        configsListView.focus = true;
                    }
                }
            }

            // ================= VIEW 5: PROYECTOS QT/C++ (ESCANEO DINÁMICO) =================
            Item {
                id: projectsView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 5

                onVisibleChanged: {
                    if (visible) {
                        projectsListView.model = configManager.getQtProjects();
                        projectsListView.focus = true;
                    }
                }

                Text {
                    id: projectsTitle
                    text: "💻  PROYECTOS QT / C++ (~/dotfiles/src)"
                    color: root.accent
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 13
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                ListView {
                    id: projectsListView
                    anchors.top: projectsTitle.bottom
                    anchors.topMargin: 15
                    anchors.bottom: backButtonProjects.top
                    anchors.bottomMargin: 10
                    width: parent.width
                    clip: true
                    spacing: 4

                    delegate: Rectangle {
                        width: projectsListView.width
                        height: 34
                        color: ListView.isCurrentItem ? root.cardBg : "transparent"
                        radius: 6
                        border.color: ListView.isCurrentItem ? root.accent : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12

                            Text {
                                text: modelData.icon
                                color: ListView.isCurrentItem ? root.accent : root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.name
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: projectsListView.currentIndex = index
                            onClicked: {
                                root.selectedProjectPath = modelData.path;
                                root.selectedProjectName = modelData.name;
                                root.currentView = 6;
                            }
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (count > 0 && currentIndex >= 0) {
                                var proj = model[currentIndex];
                                root.selectedProjectPath = proj.path;
                                root.selectedProjectName = proj.name;
                                root.currentView = 6;
                            }
                            event.accepted = true;
                        }
                    }
                }

                Button {
                    id: backButtonProjects
                    text: "  Volver"
                    flat: true
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    anchors.bottom: parent.bottom
                    contentItem: Text { text: parent.text; font: parent.font; color: root.accent }
                    onClicked: {
                        root.currentView = 3;
                        configsListView.focus = true;
                    }
                }
            }

            // ================= VIEW 6: ARCHIVOS DEL PROYECTO SELECCIONADO =================
            Item {
                id: filesView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 6

                onVisibleChanged: {
                    if (visible) {
                        filesListView.model = configManager.getProjectFiles(root.selectedProjectPath);
                        filesListView.focus = true;
                    }
                }

                Text {
                    id: filesTitle
                    text: "  " + root.selectedProjectName.toUpperCase() + " / ARCHIVOS"
                    color: root.accent
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 13
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                ListView {
                    id: filesListView
                    anchors.top: filesTitle.bottom
                    anchors.topMargin: 15
                    anchors.bottom: backButtonFiles.top
                    anchors.bottomMargin: 10
                    width: parent.width
                    clip: true
                    spacing: 4

                    delegate: Rectangle {
                        width: filesListView.width
                        height: 34
                        color: ListView.isCurrentItem ? root.cardBg : "transparent"
                        radius: 6
                        border.color: ListView.isCurrentItem ? root.accent : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12

                            Text {
                                text: modelData.icon
                                color: ListView.isCurrentItem ? root.accent : root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.name
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: filesListView.currentIndex = index
                            onClicked: {
                                configManager.editConfig(modelData.name, modelData.path);
                                root.visible = false;
                            }
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (count > 0 && currentIndex >= 0) {
                                var fileItem = model[currentIndex];
                                configManager.editConfig(fileItem.name, fileItem.path);
                                root.visible = false;
                            }
                            event.accepted = true;
                        }
                    }
                }

                Button {
                    id: backButtonFiles
                    text: "  Volver"
                    flat: true
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    anchors.bottom: parent.bottom
                    contentItem: Text { text: parent.text; font: parent.font; color: root.accent }
                    onClicked: {
                        root.currentView = 5;
                        projectsListView.focus = true;
                    }
                }
            }

            // ================= VIEW 1: BUSCADOR NIXPKGS =================
            Item {
                id: searchView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 1

                onVisibleChanged: {
                    if (visible) {
                        nixpkgsSearchInput.text = "";
                        nixpkgsSearchInput.forceActiveFocus();
                        packageListView.model = nixpkgsSearcher.packages;
                    }
                }

                property string selectedPkg: ""
                property bool showingDialog: false

                Column {
                    anchors.fill: parent
                    spacing: 12

                    // Input Box
                    Rectangle {
                        width: parent.width
                        height: 40
                        color: Qt.darker(root.bg, 1.2)
                        radius: 6
                        border.color: nixpkgsSearchInput.activeFocus ? root.accent : "transparent"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: ""
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextField {
                                id: nixpkgsSearchInput
                                width: parent.width - 30
                                placeholderText: "Buscar paquete..."
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13
                                color: root.fg
                                background: null
                                anchors.verticalCenter: parent.verticalCenter
                                placeholderTextColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.35)

                                onTextChanged: {
                                    searchView.selectedPkg = "";
                                    packageListView.model = nixpkgsSearcher.search(text);
                                }

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Down && packageListView.count > 0) {
                                        packageListView.focus = true;
                                        packageListView.currentIndex = 0;
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }

                    // Resultados
                    Rectangle {
                        width: parent.width
                        height: parent.height - 110
                        color: Qt.darker(root.bg, 1.2)
                        radius: 6
                        clip: true

                        ListView {
                            id: packageListView
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2
                            highlightMoveDuration: 100

                            delegate: Rectangle {
                                width: packageListView.width
                                height: 32
                                color: ListView.isCurrentItem ? root.cardBg : "transparent"
                                radius: 4
                                border.color: ListView.isCurrentItem ? root.accent : "transparent"
                                border.width: 1

                                Text {
                                    text: "  " + modelData
                                    color: root.fg
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: packageListView.currentIndex = index
                                    onClicked: {
                                        searchView.selectedPkg = modelData;
                                        searchView.showingDialog = true;
                                    }
                                }
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (count > 0 && currentIndex >= 0) {
                                        searchView.selectedPkg = model[currentIndex];
                                        searchView.showingDialog = true;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up && currentIndex === 0) {
                                    nixpkgsSearchInput.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Volver
                    Button {
                        text: "  Volver al menú"
                        flat: true
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: root.accent
                        }
                        onClicked: {
                            root.currentView = 0;
                            mainMenuListView.focus = true;
                        }
                    }
                }

                // Modal de acciones del paquete
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0,0,0,0.6)
                    visible: searchView.showingDialog
                    radius: 12

                    Rectangle {
                        width: 320
                        height: 160
                        color: root.bg
                        radius: 8
                        border.color: root.accent
                        border.width: 1
                        anchors.centerIn: parent

                        Column {
                            anchors.centerIn: parent
                            spacing: 15
                            width: parent.width - 30

                            Text {
                                text: "Paquete: " + searchView.selectedPkg
                                color: root.fg
                                font.family: "JetBrains Mono"
                                font.bold: true
                                font.pixelSize: 13
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                spacing: 10
                                anchors.horizontalCenter: parent.horizontalCenter

                                Button {
                                    text: "  Probar"
                                    font.family: "JetBrains Mono"
                                    contentItem: Text { text: parent.text; font: parent.font; color: root.fg }
                                    background: Rectangle { color: root.cardBg; radius: 6 }
                                    onClicked: {
                                        nixpkgsSearcher.runTemp(searchView.selectedPkg);
                                        Qt.quit();
                                    }
                                }

                                Button {
                                    text: "  Instalar"
                                    font.family: "JetBrains Mono"
                                    contentItem: Text { text: parent.text; font: parent.font; color: root.bg }
                                    background: Rectangle { color: root.accent; radius: 6 }
                                    onClicked: {
                                        nixpkgsSearcher.installPermanent(searchView.selectedPkg);
                                        Qt.quit();
                                    }
                                }

                                Button {
                                    text: "Cancelar"
                                    font.family: "JetBrains Mono"
                                    contentItem: Text { text: parent.text; font: parent.font; color: root.fg; opacity: 0.6 }
                                    background: Rectangle { color: "transparent"; radius: 6 }
                                    onClicked: searchView.showingDialog = false;
                                }
                            }
                        }
                    }
                }
            }

            // ================= VIEW 2: INSTALADOR WEB APPS (PWAs) =================
            Item {
                id: pwaView
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentView === 2

                onVisibleChanged: {
                    if (visible) {
                        pwaName.text = "";
                        pwaUrl.text = "";
                        pwaIcon.text = "";
                        pwaName.forceActiveFocus();
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        text: "🌐  NUEVA WEB APP"
                        color: root.accent
                        font.family: "JetBrains Mono"
                        font.bold: true
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Column {
                        width: parent.width
                        spacing: 10

                        Column {
                            width: parent.width
                            spacing: 4
                            Text { text: "Nombre de la Aplicación"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 11; opacity: 0.7 }
                            Rectangle {
                                width: parent.width; height: 35; color: Qt.darker(root.bg, 1.2); radius: 6; border.color: pwaName.activeFocus ? root.accent : "transparent"
                                TextField { id: pwaName; anchors.fill: parent; anchors.leftMargin: 8; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 12; background: null }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            Text { text: "Dirección URL"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 11; opacity: 0.7 }
                            Rectangle {
                                width: parent.width; height: 35; color: Qt.darker(root.bg, 1.2); radius: 6; border.color: pwaUrl.activeFocus ? root.accent : "transparent"
                                TextField { id: pwaUrl; anchors.fill: parent; anchors.leftMargin: 8; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 12; background: null; placeholderText: "https://..." }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            Text { text: "Icono de la App"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 11; opacity: 0.7 }
                            Row {
                                width: parent.width
                                spacing: 8
                                Rectangle {
                                    width: parent.width - 90; height: 35; color: Qt.darker(root.bg, 1.2); radius: 6
                                    TextField { id: pwaIcon; anchors.fill: parent; anchors.leftMargin: 8; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 11; background: null; placeholderText: "Ícono o imagen..." }
                                }
                                Button {
                                    text: "  Buscar"
                                    width: 82; height: 35
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    contentItem: Text { text: parent.text; font: parent.font; color: root.fg; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { color: root.cardBg; radius: 6 }
                                    onClicked: iconDialog.open()
                                }
                            }
                        }
                    }

                    FileDialog {
                        id: iconDialog
                        title: "Selecciona un ícono para la Web App"
                        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
                        nameFilters: [ "Imágenes (*.png *.jpg *.jpeg *.svg)" ]
                        onAccepted: pwaIcon.text = iconDialog.selectedFile
                    }

                    Item { width: 10; height: 5 }

                    Button {
                        text: "󰖟  Crear Web App"
                        width: parent.width
                        height: 38
                        font.family: "JetBrains Mono"
                        font.bold: true
                        font.pixelSize: 12
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: root.bg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: root.accent
                            radius: 6
                        }
                        onClicked: {
                            if (pwaManager.createPwa(pwaName.text, pwaUrl.text, pwaIcon.text)) {
                                pwaName.text = "";
                                pwaUrl.text = "";
                                pwaIcon.text = "";
                                root.currentView = 0;
                                mainMenuListView.focus = true;
                            }
                        }
                    }

                    Button {
                        text: "  Volver al menú"
                        flat: true
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: root.accent
                        }
                        onClicked: {
                            root.currentView = 0;
                            mainMenuListView.focus = true;
                        }
                    }
                }
            }
        }
    }

    // Disparador de acciones en la vista de configuración
    function triggerConfigAction(type, name, path) {
        if (type === "static" || type === "config") {
            configManager.editConfig(name, path);
            root.visible = false;
        } else if (type === "view") {
            var targetView = parseInt(path);
            root.currentView = targetView;
        }
    }
}
