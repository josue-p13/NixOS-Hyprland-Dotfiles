import QtQuick
import QtQuick.Controls
import org.kde.layershell 1.0 as LayerShell
import org.kde.layershell 1.0 as LS

ApplicationWindow {
    id: root
    visible: false
    width: 840
    height: 440
    color: "transparent"
    
    // LayerOverlay so it displays on top of all normal windows when active
    LayerShell.Window.layer: LS.Window.LayerOverlay
    
    // Centered horizontally, anchored to the top
    LayerShell.Window.anchors: LS.Window.AnchorTop
    
    LayerShell.Window.margins.top: root.topMarginValue
    
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: active ? LS.Window.KeyboardInteractivityExclusive : LS.Window.KeyboardInteractivityNone

    Shortcut {
        sequence: "Escape"
        onActivated: dashboardManager.active = false
    }
    
    property real topMarginValue: 15
    property real scaleValue: 0.85
    property real opacityValue: 0.0
    property int currentTab: 0

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: root.visible
    }

    property real globalWavePhase: 0
    NumberAnimation on globalWavePhase {
        from: 0; to: Math.PI * 2
        duration: 1800
        loops: Animation.Infinite
        running: root.visible
    }
    
    // Bind to the C++ DashboardManager state
    readonly property bool active: dashboardManager.active
    
    onActiveChanged: {
        if (active) {
            showAnim.start()
            card.forceActiveFocus()
        } else {
            hideAnim.start()
        }
    }
    
    SequentialAnimation {
        id: showAnim
        ScriptAction { script: { root.visible = true; } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "topMarginValue"; to: 45; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "scaleValue"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacityValue"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
        }
    }
    
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "topMarginValue"; to: 15; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "scaleValue"; to: 0.85; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "opacityValue"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.visible = false; } }
    }

    // Helper functions and theme resolving
    readonly property color c_bg: themeManager.colors["background"] || "#282828"
    readonly property color c_fg: themeManager.colors["foreground"] || "#ebdbb2"
    
    function getThemeColor(name, fallback) {
        if (themeManager.colors && themeManager.colors["colors"]) {
            var val = themeManager.colors["colors"][name];
            if (val) return val;
        }
        return fallback;
    }
    
    readonly property color c_red: getThemeColor("color1", "#fb4934")
    readonly property color c_green: getThemeColor("color2", "#b8bb26")
    readonly property color c_yellow: getThemeColor("color3", "#fabd2f")
    readonly property color c_blue: getThemeColor("color4", "#83a598")
    readonly property color c_purple: getThemeColor("color5", "#d3869b")
    readonly property color c_orange: getThemeColor("color6", "#fe8019")
    readonly property color c_gray: getThemeColor("color8", "#928374")

    // Dynamic color depending on the hour of the day for the clock
    readonly property color timeAccentColor: {
        var h = new Date().getHours();
        if (h >= 5 && h < 12) return root.c_orange;  // Morning: Orange/Peach
        if (h >= 12 && h < 17) return root.c_blue;   // Afternoon: Blue/Sapphire
        if (h >= 17 && h < 21) return root.c_purple; // Evening: Mauve/Purple
        return root.c_yellow;                        // Night: Yellow
    }

    function hexToRgba(hex, alpha) {
        if (!hex) return Qt.rgba(40/255.0, 40/255.0, 40/255.0, alpha);
        var hexStr = hex.toString().replace("#", "");
        if (hexStr.length === 8) {
            hexStr = hexStr.substring(0, 6);
        }
        if (hexStr.length !== 6) return Qt.rgba(40/255.0, 40/255.0, 40/255.0, alpha);
        var r = parseInt(hexStr.substring(0, 2), 16) / 255.0;
        var g = parseInt(hexStr.substring(2, 4), 16) / 255.0;
        var b = parseInt(hexStr.substring(4, 6), 16) / 255.0;
        return Qt.rgba(r, g, b, alpha);
    }

    function formatBytes(bytes) {
        if (bytes === undefined || isNaN(bytes)) return "0 B/s";
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024) return (bytes / 1024).toFixed(0) + " KB/s";
        return bytes.toFixed(0) + " B/s";
    }

    ListModel {
        id: calendarModel
    }

    function capitalize(s) {
        if (typeof s !== 'string') return '';
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function updateDateTime() {
        var d = new Date();
        timeLabel.text = Qt.formatTime(d, "HH:mm");
        dateLabel.text = capitalize(d.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM"));
    }

    function updateCalendar() {
        calendarModel.clear();
        var now = new Date();
        var year = now.getFullYear();
        var month = now.getMonth();
        
        var firstDay = new Date(year, month, 1);
        var startDayOffset = firstDay.getDay();
        startDayOffset = (startDayOffset === 0) ? 6 : startDayOffset - 1;
        
        var totalDays = new Date(year, month + 1, 0).getDate();
        var prevTotalDays = new Date(year, month, 0).getDate();
        
        for (var i = 0; i < 42; i++) {
            var dayNum = 0;
            var isCurrentMonth = false;
            var isToday = false;
            
            if (i < startDayOffset) {
                dayNum = prevTotalDays - startDayOffset + i + 1;
            } else if (i < startDayOffset + totalDays) {
                dayNum = i - startDayOffset + 1;
                isCurrentMonth = true;
                if (dayNum === now.getDate() && month === now.getMonth() && year === now.getFullYear()) {
                    isToday = true;
                }
            } else {
                dayNum = i - startDayOffset - totalDays + 1;
            }
            
            calendarModel.append({
                "dayNumber": dayNum,
                "isCurrent": isCurrentMonth,
                "isToday": isToday
            });
        }
    }

    // Inline Components
    component TabButton : Rectangle {
        id: btn
        property int tabId
        property string iconText
        property string labelText
        property color activeColor: root.c_orange
        
        width: 120
        height: 34
        radius: 10
        color: root.currentTab === btn.tabId ? hexToRgba(btn.activeColor, 0.15) : hexToRgba(root.c_bg, 0.4)
        border.width: 1
        border.color: root.currentTab === btn.tabId ? btn.activeColor : hexToRgba(root.c_fg, 0.1)
        scale: mouseArea.containsMouse ? 1.04 : 1.0
        
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        
        Row {
            anchors.centerIn: parent
            spacing: 6
            
            Text {
                text: btn.iconText
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                color: root.currentTab === btn.tabId ? btn.activeColor : root.c_fg
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            
            Text {
                text: btn.labelText
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.bold: true
                color: root.currentTab === btn.tabId ? btn.activeColor : root.c_fg
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.currentTab = btn.tabId
            
            onEntered: {
                if (root.currentTab !== btn.tabId) {
                    btn.border.color = btn.activeColor
                }
            }
            onExited: {
                if (root.currentTab !== btn.tabId) {
                    btn.border.color = hexToRgba(root.c_fg, 0.1)
                }
            }
        }
    }

    component SystemCard : Rectangle {
        id: sysCard
        property string title
        property real value
        property string valueText
        property string subText
        property color accentColor
        property string iconText: ""
        
        width: 180
        height: 300
        radius: 18
        color: hexToRgba(root.c_bg, 0.3)
        border.width: 1
        border.color: hexToRgba(sysCard.accentColor, 0.25)
        clip: true

        property real fillRatio: Math.max(0.0, Math.min(1.0, sysCard.value / 100.0))
        property real fillY: height * (1.0 - sysCard.fillRatio)
        property real waveAmp: (sysCard.fillRatio < 0.99 && sysCard.fillRatio > 0.01) ? 6 * Math.sin(sysCard.fillRatio * Math.PI) : 0
        property real waveCenterOffset: 0.375 * sysCard.waveAmp * (Math.sin(root.globalWavePhase) - Math.cos(root.globalWavePhase))

        // Canvas for drawing the wave fluid
        Canvas {
            id: fluidCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (sysCard.value <= 0) return;

                ctx.save();
                
                var r = 18; // radius
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(width - r, 0);
                ctx.quadraticCurveTo(width, 0, width, r);
                ctx.lineTo(width, height - r);
                ctx.quadraticCurveTo(width, height, width - r, height);
                ctx.lineTo(r, height);
                ctx.quadraticCurveTo(0, height, 0, height - r);
                ctx.lineTo(0, r);
                ctx.quadraticCurveTo(0, 0, r, 0);
                ctx.closePath();
                ctx.clip();

                ctx.beginPath();
                ctx.moveTo(0, sysCard.fillY);
                if (sysCard.waveAmp > 0) {
                    var cp1y = sysCard.fillY + Math.sin(root.globalWavePhase) * sysCard.waveAmp;
                    var cp2y = sysCard.fillY + Math.cos(root.globalWavePhase + Math.PI) * sysCard.waveAmp;
                    ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, sysCard.fillY);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                } else {
                    ctx.lineTo(width, sysCard.fillY);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                }
                ctx.closePath();

                var grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, hexToRgba(sysCard.accentColor, 0.85).toString());
                grad.addColorStop(1, hexToRgba(sysCard.accentColor, 0.4).toString());
                ctx.fillStyle = grad;
                ctx.globalAlpha = 0.95;
                ctx.fill();
                ctx.restore();
            }

            Connections {
                target: root
                enabled: root.visible && sysCard.visible && sysCard.value > 0
                function onGlobalWavePhaseChanged() { fluidCanvas.requestPaint(); }
            }
        }

        // Layer 1: Regular text labels (placed at bottom)
        Item {
            anchors.fill: parent
            anchors.margins: 16

            Text {
                id: baseIcon
                anchors.top: parent.top
                anchors.left: parent.left
                font.family: "JetBrains Mono"
                font.pixelSize: 18
                color: hexToRgba(root.c_fg, 0.5)
                text: sysCard.iconText
            }

            Text {
                anchors.verticalCenter: baseIcon.verticalCenter 
                anchors.right: parent.right
                font.family: "JetBrains Mono"
                font.bold: true
                font.pixelSize: 11
                color: hexToRgba(root.c_fg, 0.5)
                text: sysCard.title
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 4
                font.family: "JetBrains Mono"
                font.bold: true
                font.pixelSize: 12
                color: hexToRgba(root.c_fg, 0.7)
                text: sysCard.subText
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                font.family: "JetBrains Mono"
                font.bold: true
                font.pixelSize: 28
                color: root.c_fg
                text: sysCard.valueText
            }
        }

        // Layer 2: Masked/Clipped Text labels (placed inside waveClipBox)
        Item {
            id: waveClipBox
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(parent.height, Math.max(0, (parent.height * sysCard.fillRatio) - sysCard.waveCenterOffset))
            clip: true
            visible: sysCard.value > 0

            Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: sysCard.height
                anchors.margins: 16

                Text {
                    id: filledIcon
                    anchors.top: parent.top
                    anchors.left: parent.left
                    font.family: "JetBrains Mono"
                    font.pixelSize: 18
                    color: hexToRgba(root.c_bg, 0.95)
                    text: sysCard.iconText
                }

                Text {
                    anchors.verticalCenter: filledIcon.verticalCenter 
                    anchors.right: parent.right
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 11
                    color: hexToRgba(root.c_bg, 0.95)
                    text: sysCard.title
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.bottomMargin: 4
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 12
                    color: hexToRgba(root.c_bg, 0.95)
                    text: sysCard.subText
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 28
                    color: hexToRgba(root.c_bg, 0.95)
                    text: sysCard.valueText
                }
            }
        }
    }

    // Main Card Container
    Rectangle {
        id: card
        anchors.fill: parent
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                dashboardManager.active = false;
                event.accepted = true;
            }
        }
        anchors.margins: 10
        radius: 26
        opacity: root.opacityValue
        scale: root.scaleValue
        clip: true
        
        // Translucent background
        color: hexToRgba(root.c_bg, 0.85)

        // --- Orbiting Ambient Lava-Lamp Glows ---
        Rectangle {
            width: parent.width * 0.5; height: width; radius: width / 2
            x: (parent.width * 0.75 - width / 2) + Math.cos(root.globalOrbitAngle * 1.5) * 200
            y: (parent.height * 0.3 - height / 2) + Math.sin(root.globalOrbitAngle * 1.5) * 120
            opacity: 0.04
            color: root.timeAccentColor
            Behavior on color { ColorAnimation { duration: 1000 } }
        }
        Rectangle {
            width: parent.width * 0.6; height: width; radius: width / 2
            x: (parent.width * 0.25 - width / 2) + Math.sin(root.globalOrbitAngle * 1.2) * -180
            y: (parent.height * 0.7 - height / 2) + Math.cos(root.globalOrbitAngle * 1.2) * -150
            opacity: 0.03
            color: root.c_purple
            Behavior on color { ColorAnimation { duration: 1000 } }
        }
        Rectangle {
            width: parent.width * 0.45; height: width; radius: width / 2
            x: (parent.width * 0.5 - width / 2) + Math.cos(root.globalOrbitAngle * -1.8) * 220
            y: (parent.height * 0.5 - height / 2) + Math.sin(root.globalOrbitAngle * -1.8) * -200
            opacity: 0.02
            color: root.c_orange
            Behavior on color { ColorAnimation { duration: 1000 } }
        }
        
        border.width: 2
        border.color: root.currentTab === 0 ? root.c_yellow : (root.currentTab === 1 ? root.c_green : root.c_red)
        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Main Layout Stack
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // --- HEADER: Title and Tabs ---
            Item {
                width: parent.width
                height: 36
                
                Row {
                    id: tabsRow
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    
                    TabButton {
                        id: btn0
                        tabId: 0
                        iconText: "󰥔"
                        labelText: "Reloj"
                        activeColor: root.c_yellow
                    }
                    TabButton {
                        id: btn1
                        tabId: 1
                        iconText: "󰘚"
                        labelText: "Consumo"
                        activeColor: root.c_green
                    }
                    TabButton {
                        id: btn2
                        tabId: 2
                        iconText: "󰓇"
                        labelText: "Música"
                        activeColor: root.c_red
                    }
                }
            }

            // Separator with Sliding Indicator
            Item {
                width: parent.width
                height: 5
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: hexToRgba(root.c_gray, 0.25)
                    anchors.bottom: parent.bottom
                }
                
                Rectangle {
                    id: tabIndicator
                    x: tabsRow.x + (root.currentTab === 0 ? btn0.x : (root.currentTab === 1 ? btn1.x : btn2.x)) + 10
                    y: 1
                    width: (root.currentTab === 0 ? btn0.width : (root.currentTab === 1 ? btn1.width : btn2.width)) - 20
                    height: 3
                    radius: 1.5
                    color: root.currentTab === 0 ? root.c_yellow : (root.currentTab === 1 ? root.c_green : root.c_red)
                    
                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // --- CONTENT AREA ---
            Item {
                width: parent.width
                height: 320

                // TAB 0: Clock & Calendar
                Item {
                    anchors.fill: parent
                    visible: root.currentTab === 0

                    // Vertical Divider (perfectly centered)
                    Rectangle {
                        id: tab0Divider
                        width: 1
                        height: 280
                        color: hexToRgba(root.c_gray, 0.2)
                        anchors.centerIn: parent
                    }

                    // Left: Clock & Date (Minimalist)
                    Column {
                        id: clockCol
                        width: 360
                        spacing: 12
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: tab0Divider.left
                        anchors.rightMargin: 40
                        
                        Label {
                            id: timeLabel
                            font.family: "JetBrains Mono"
                            font.pixelSize: 84
                            font.bold: true
                            color: root.timeAccentColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Label {
                            id: dateLabel
                            font.family: "JetBrains Mono"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.c_fg
                            opacity: 0.85
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Right: Calendar
                    Column {
                        id: calendarCol
                        width: 340
                        spacing: 12
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: tab0Divider.right
                        anchors.leftMargin: 40
                        
                        Label {
                            text: {
                                var months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
                                var now = new Date();
                                return months[now.getMonth()] + " " + now.getFullYear();
                            }
                            font.family: "JetBrains Mono"
                            font.pixelSize: 15
                            font.bold: true
                            color: root.c_orange
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Row {
                            spacing: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            Repeater {
                                model: ["L", "M", "M", "J", "V", "S", "D"]
                                delegate: Label {
                                    width: 36
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: index >= 5 ? root.c_red : root.c_gray
                                }
                            }
                        }
                        
                        Grid {
                            columns: 7
                            spacing: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Repeater {
                                model: calendarModel
                                delegate: Rectangle {
                                    id: cell
                                    width: 36
                                    height: 36
                                    radius: 8
                                    color: model.isToday ? root.c_orange : (model.isCurrent ? hexToRgba(root.c_bg, 0.3) : "transparent")
                                    border.width: model.isToday ? 0 : 1
                                    border.color: mouseArea.containsMouse ? root.c_orange : (model.isCurrent ? hexToRgba(root.c_fg, 0.1) : "transparent")
                                    scale: mouseArea.containsMouse ? 1.1 : 1.0
                                    
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    
                                    // Pulse circle behind today
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 32; height: 32; radius: 16
                                        color: root.c_orange
                                        opacity: 0
                                        visible: model.isToday
                                        
                                        SequentialAnimation on scale {
                                            loops: Animation.Infinite
                                            running: model.isToday && root.visible
                                            NumberAnimation { from: 1.0; to: 1.5; duration: 1600; easing.type: Easing.OutQuad }
                                        }
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            running: model.isToday && root.visible
                                            NumberAnimation { from: 0.5; to: 0.0; duration: 1600; easing.type: Easing.OutQuad }
                                        }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.dayNumber
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 11
                                        font.bold: model.isToday || model.isCurrent
                                        color: model.isToday ? root.c_bg : (model.isCurrent ? root.c_fg : hexToRgba(root.c_fg, 0.3))
                                    }
                                    
                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }

                // TAB 1: Consumption / Resource Usage
                Row {
                    anchors.centerIn: parent
                    width: 768
                    height: 300
                    visible: root.currentTab === 1
                    spacing: 16

                    SystemCard {
                        title: "PROCESADOR"
                        iconText: ""
                        value: systemMonitor.cpu
                        valueText: Math.round(systemMonitor.cpu) + "%"
                        subText: "Temp: " + Math.round(systemMonitor.temp) + "°C"
                        accentColor: root.c_yellow
                    }

                    SystemCard {
                        title: "MEMORIA"
                        iconText: ""
                        value: systemMonitor.ram
                        valueText: Math.round(systemMonitor.ram) + "%"
                        subText: "Carga RAM"
                        accentColor: root.c_orange
                    }

                    SystemCard {
                        title: "GRÁFICOS"
                        iconText: "󰢮"
                        value: systemMonitor.gpu
                        valueText: Math.round(systemMonitor.gpu) + "%"
                        subText: "Carga GPU"
                        accentColor: root.c_blue
                    }

                    SystemCard {
                        title: "ALMACENAMIENTO"
                        iconText: "󰋊"
                        value: systemMonitor.disk
                        valueText: Math.round(systemMonitor.disk) + "%"
                        subText: "Red Rx/Tx:\n" + root.formatBytes(systemMonitor.rxRate) + "\n" + root.formatBytes(systemMonitor.txRate)
                        accentColor: root.c_green
                    }
                }

                // TAB 2: Music / Player
                Item {
                    anchors.fill: parent
                    visible: root.currentTab === 2

                    // If Spotify is running
                    Item {
                        id: spotifyActiveContainer
                        anchors.fill: parent
                        visible: spotifyPlayer.hasMusic

                        // Left: Art and Equalizer
                        Column {
                            id: spotifyLeftCol
                            width: 180
                            spacing: 16
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 40

                            Rectangle {
                                width: 180
                                height: 180
                                radius: 16
                                color: hexToRgba(root.c_bg, 0.4)
                                border.width: 2
                                border.color: root.c_red
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: spotifyPlayer.albumArt || ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: spotifyPlayer.albumArt !== ""
                                }
                                
                                // Fallback icon
                                Label {
                                    anchors.centerIn: parent
                                    visible: spotifyPlayer.albumArt === ""
                                    text: "󰓇"
                                    font.pixelSize: 72
                                    color: root.c_red
                                }
                            }

                            // Equalizer Row with 14 bars and vertical gradients
                            Row {
                                id: eqRow
                                width: parent.width
                                height: 32
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: spotifyPlayer.isPlaying
                                
                                property var barHeights: [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]
                                
                                Repeater {
                                    model: 14
                                    Rectangle {
                                        width: (eqRow.width - 13 * 4) / 14
                                        height: eqRow.barHeights[index]
                                        anchors.bottom: parent.bottom
                                        radius: 2
                                        
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: root.c_orange }
                                            GradientStop { position: 1.0; color: root.c_red }
                                        }
                                        
                                        Behavior on height {
                                            NumberAnimation { duration: 60; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }
                        }

                        // Right: Metadata, Controls, and Equalizer
                        Column {
                            id: spotifyRightCol
                            width: parent.width - 180 - 36 - 80
                            spacing: 12
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: spotifyLeftCol.right
                            anchors.leftMargin: 36

                            // Top Part: Song Info & Playback Controls side-by-side
                            Item {
                                width: parent.width
                                height: 50

                                Column {
                                    width: parent.width - 140
                                    spacing: 4
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    Label {
                                        width: parent.width
                                        text: spotifyPlayer.title
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 18
                                        font.bold: true
                                        color: root.c_yellow
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        width: parent.width
                                        text: spotifyPlayer.artist
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: root.c_fg
                                        elide: Text.ElideRight
                                        opacity: 0.8
                                    }
                                }

                                // Playback Controls Row
                                Row {
                                    spacing: 8
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Prev
                                    Rectangle {
                                        id: prevBtn
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: prevMouse.containsMouse ? hexToRgba(root.c_red, 0.2) : hexToRgba(root.c_bg, 0.4)
                                        border.width: 1
                                        border.color: prevMouse.containsMouse ? root.c_red : hexToRgba(root.c_fg, 0.1)
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒮"
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 14
                                            color: prevMouse.containsMouse ? root.c_red : root.c_fg
                                        }
                                        
                                        MouseArea {
                                            id: prevMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: spotifyPlayer.previous()
                                        }
                                    }

                                    // Play
                                    Rectangle {
                                        id: playBtn
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: playMouse.containsMouse ? hexToRgba(root.c_red, 0.2) : hexToRgba(root.c_bg, 0.4)
                                        border.width: 1
                                        border.color: playMouse.containsMouse ? root.c_red : hexToRgba(root.c_fg, 0.1)
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: spotifyPlayer.isPlaying ? "󰏤" : "󰐊"
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 18
                                            color: playMouse.containsMouse ? root.c_red : root.c_fg
                                        }
                                        
                                        MouseArea {
                                            id: playMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: spotifyPlayer.playPause()
                                        }
                                    }

                                    // Next
                                    Rectangle {
                                        id: nextBtn
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: nextMouse.containsMouse ? hexToRgba(root.c_red, 0.2) : hexToRgba(root.c_bg, 0.4)
                                        border.width: 1
                                        border.color: nextMouse.containsMouse ? root.c_red : hexToRgba(root.c_fg, 0.1)
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒭"
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 14
                                            color: nextMouse.containsMouse ? root.c_red : root.c_fg
                                        }
                                        
                                        MouseArea {
                                            id: nextMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: spotifyPlayer.next()
                                        }
                                    }
                                }
                            }

                            // Horizontal Divider
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: hexToRgba(root.c_fg, 0.1)
                            }

                            // Equalizer Header
                            Item {
                                width: parent.width
                                height: 30

                                Row {
                                    spacing: 8
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    Label {
                                        text: "Equalizer"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: root.c_red
                                    }

                                    Label {
                                        text: "(" + (equalizerManager.eqData.preset || "Flat") + ")"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 11
                                        color: hexToRgba(root.c_fg, 0.6)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Apply Button
                                Rectangle {
                                    id: applyBtn
                                    width: 65
                                    height: 22
                                    radius: 5
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: equalizerManager.eqData.pending ? root.c_red : hexToRgba(root.c_bg, 0.4)
                                    border.width: 1
                                    border.color: equalizerManager.eqData.pending ? root.c_red : hexToRgba(root.c_fg, 0.1)
                                    visible: equalizerManager.eqData.pending

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Aplicar"
                                        color: equalizerManager.eqData.pending ? root.c_bg : root.c_fg
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            equalizerManager.apply()
                                        }
                                    }
                                }
                            }

                            // 10 Sliders Row
                            Row {
                                id: eqSliderRow
                                width: parent.width
                                height: 110
                                spacing: (width - (10 * 20)) / 9

                                Repeater {
                                    model: [
                                        {"idx": 1, "lbl": "31"}, {"idx": 2, "lbl": "63"}, {"idx": 3, "lbl": "125"},
                                        {"idx": 4, "lbl": "250"}, {"idx": 5, "lbl": "500"}, {"idx": 6, "lbl": "1k"},
                                        {"idx": 7, "lbl": "2k"}, {"idx": 8, "lbl": "4k"}, {"idx": 9, "lbl": "8k"},
                                        {"idx": 10, "lbl": "16k"}
                                    ]
                                    delegate: Item {
                                        width: 20
                                        height: eqSliderRow.height

                                        Slider {
                                            id: eqSlider
                                            anchors.top: parent.top
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.width
                                            height: 90
                                            orientation: Qt.Vertical
                                            from: -12
                                            to: 12
                                            stepSize: 1

                                            Binding {
                                                target: eqSlider
                                                property: "value"
                                                value: equalizerManager.eqData["b" + modelData.idx] !== undefined ? Number(equalizerManager.eqData["b" + modelData.idx]) : 0.0
                                                when: !eqSlider.pressed
                                            }

                                            onMoved: {
                                                equalizerManager.setBand(modelData.idx, Math.round(value))
                                            }

                                            Behavior on value {
                                                enabled: !eqSlider.pressed
                                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                                            }

                                            background: Rectangle {
                                                x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                                y: eqSlider.topPadding
                                                width: 4; height: eqSlider.availableHeight
                                                radius: 2
                                                color: hexToRgba(root.c_fg, 0.1)

                                                Rectangle {
                                                    width: parent.width
                                                    height: (1 - eqSlider.visualPosition) * parent.height
                                                    y: eqSlider.visualPosition * parent.height
                                                    radius: 2
                                                    color: root.c_red
                                                }
                                            }

                                            handle: Rectangle {
                                                x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                                y: eqSlider.topPadding + eqSlider.visualPosition * (eqSlider.availableHeight - height)
                                                width: 12; height: 12
                                                radius: 6
                                                color: eqSlider.pressed ? root.c_yellow : root.c_fg
                                                border.width: 1
                                                border.color: hexToRgba(root.c_bg, 0.6)
                                            }
                                        }

                                        Label {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.lbl
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 9
                                            color: hexToRgba(root.c_fg, 0.5)
                                        }
                                    }
                                }
                            }

                            // Presets Grid
                            Grid {
                                id: presetsGrid
                                width: parent.width
                                columns: 4
                                spacing: 8

                                Repeater {
                                    model: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
                                    delegate: Rectangle {
                                        width: (presetsGrid.width - 3 * 8) / 4
                                        height: 24
                                        radius: 6
                                        
                                        readonly property bool isActive: equalizerManager.eqData.preset === modelData
                                        color: isActive ? root.c_red : (presetMouse.containsMouse ? hexToRgba(root.c_fg, 0.15) : hexToRgba(root.c_bg, 0.4))
                                        border.width: 1
                                        border.color: isActive ? root.c_red : hexToRgba(root.c_fg, 0.1)
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: isActive ? root.c_bg : root.c_fg
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: presetMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                equalizerManager.applyPreset(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // If Spotify is Closed
                    Column {
                        anchors.centerIn: parent
                        visible: !spotifyPlayer.hasMusic
                        spacing: 16

                        Label {
                            text: "(⇀_⇀) . z Z"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 42
                            font.bold: true
                            color: root.c_gray
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Label {
                            text: "Spotify cerrado. Inicia la música"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 14
                            font.bold: true
                            color: root.c_yellow
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        updateCalendar();
        updateDateTime();
    }

    // Timer for time and date
    Timer {
        id: dateTimeTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            updateDateTime();
            var now = new Date();
            if (now.getHours() === 0 && now.getMinutes() === 0 && now.getSeconds() === 0) {
                updateCalendar();
            }
        }
    }

    // Timer for equalizer animation (14 bars)
    Timer {
        interval: 65
        running: spotifyPlayer.hasMusic && spotifyPlayer.isPlaying && root.visible
        repeat: true
        onTriggered: {
            var newHeights = [];
            for (var i = 0; i < 14; i++) {
                newHeights.push(Math.floor(Math.random() * 24) + 4);
            }
            eqRow.barHeights = newHeights;
        }
    }

    // Utility function to draw glowing circular gauge rings with linear gradients
    function drawRing(ctx, w, h, val, color) {
        ctx.clearRect(0, 0, w, h);
        
        var x = w / 2;
        var y = h / 2;
        var radius = Math.min(w, h) / 2 - 6;
        
        // Background track (wider and more translucent for glassmorphic depth)
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, 2 * Math.PI, false);
        ctx.lineWidth = 6;
        ctx.strokeStyle = root.hexToRgba(root.c_gray, 0.15);
        ctx.stroke();
        
        // Active ring
        if (val > 0) {
            ctx.beginPath();
            var startAngle = -Math.PI / 2;
            var endAngle = startAngle + (val / 100.0) * 2 * Math.PI;
            ctx.arc(x, y, radius, startAngle, endAngle, false);
            ctx.lineWidth = 6;
            
            // Premium linear gradient along the ring arc
            var grad = ctx.createLinearGradient(0, 0, w, h);
            grad.addColorStop(0, color);
            grad.addColorStop(1, root.hexToRgba(color, 0.5));
            
            ctx.strokeStyle = grad;
            ctx.lineCap = "round";
            
            // Draw outer neon glow shadow on the canvas
            ctx.shadowBlur = 8;
            ctx.shadowColor = color;
            
            ctx.stroke();
            
            // Reset shadow settings
            ctx.shadowBlur = 0;
        }
    }
}
