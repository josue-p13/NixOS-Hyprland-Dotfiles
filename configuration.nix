# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help').
{ config, pkgs, ... }:
let
  # Bundle de todas las tipelibs GI necesarias para los widgets Python.
  # symlinkJoin incluye TODOS los outputs (no solo 'bin' como buildEnv).
  giTypelibs = pkgs.symlinkJoin {
    name = "gi-typelibs";
    paths = with pkgs; [
      gtk3                          # Gtk-3.0, Gdk-3.0, GdkX11-3.0
      (lib.getOutput "out" pango)             # Pango-1.0, PangoCairo-1.0 (+out tiene tipelibs)
      (lib.getOutput "out" gdk-pixbuf)        # GdkPixbuf-2.0
      (lib.getOutput "out" atk)               # Atk-1.0
      (lib.getOutput "out" glib)              # GLib-2.0, Gio-2.0, GObject-2.0
      (lib.getOutput "out" harfbuzz)          # HarfBuzz-0.0
      (lib.getOutput "out" cairo)             # cairo-1.0
      gtk-layer-shell               # GtkLayerShell-0.1
      (lib.getOutput "out" gobject-introspection) # xlib-2.0, GIRepository-2.0, DBus-1.0, etc.
      (lib.getOutput "out" fontconfig)        # fontconfig-2.0
      (lib.getOutput "out" freetype)          # freetype2-2.0
      (lib.getOutput "out" libxml2)           # libxml2-2.0
    ];
  };
  # Python con todos los paquetes que usaban tus widgets y scripts
  hyprPython = pkgs.python3.withPackages (ps: with ps; [
    pip psutil pandas numpy matplotlib pillow pygobject3
    requests pydantic sqlalchemy fastapi uvicorn opencv4
    redis spotipy
  ]);
  # Wrapper que inyecta GI_TYPELIB_PATH antes de lanzar Python.
  # Úsalo en hyprland.conf para los exec-once de los widgets.
  hyprPythonWrapped = pkgs.writeShellScriptBin "hypr-python" ''
    export GI_TYPELIB_PATH="${giTypelibs}/lib/girepository-1.0"
    exec ${hyprPython}/bin/python3 "$@"
  '';

  # Plugin hypr-dynamic-cursors compatible con Hyprland 0.55.1
  hypr-dynamic-cursors-plugin = pkgs.hyprlandPlugins.hypr-dynamic-cursors.overrideAttrs (old: {
    version = "d1fec09";
    src = pkgs.fetchFromGitHub {
      owner = "VirtCode";
      repo = "hypr-dynamic-cursors";
      rev = "d1fec0979f62d861627bc2a365a5de53ef85dd2a";
      hash = "sha256-9kUeBhi6+oFyUmvRmXAoPqRUW5Tbh/C1eQcyVkLNrwA=";
    };
  });


  # Tema de SDDM personalizado con fondo dinámico
  custom-sddm-theme = pkgs.stdenv.mkDerivation {
    name = "catppuccin-sddm-corners-custom";
    src = pkgs.catppuccin-sddm-corners;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      mkdir -p $out/share/sddm/themes
      cp -aR $src/share/sddm/themes/catppuccin-sddm-corners $out/share/sddm/themes/
      chmod -R +w $out/share/sddm/themes/catppuccin-sddm-corners
      sed -i 's|Background=.*|Background="/var/lib/sddm/background.png"|' $out/share/sddm/themes/catppuccin-sddm-corners/theme.conf
      sed -i 's|UserPictureBorderWidth=.*|UserPictureBorderWidth="3"|' $out/share/sddm/themes/catppuccin-sddm-corners/theme.conf

      python3 -c '
import os

theme_path = os.path.join(os.environ["out"], "share/sddm/themes/catppuccin-sddm-corners")

# 1. components/UserPanel.qml
file_path = os.path.join(theme_path, "components/UserPanel.qml")
with open(file_path, "r") as f:
    content = f.read()
target = """Column {
    property var username: usernameField.text"""
replacement = """Column {
    property alias usernameField: usernameField
    property var username: usernameField.text"""
content = content.replace(target, replacement)
with open(file_path, "w") as f:
    f.write(content)

# 2. components/SessionPanel.qml
file_path = os.path.join(theme_path, "components/SessionPanel.qml")
with open(file_path, "r") as f:
    content = f.read()
target = """Item {
    property var session: sessionList.currentIndex"""
replacement = """Item {
    property alias sessionButton: sessionButton
    property var session: sessionList.currentIndex"""
content = content.replace(target, replacement)

target = """        background: Rectangle {
            id: sessionButtonBg

            color: config.SessionButtonColor
            radius: config.CornerRadius
        }"""
replacement = """        background: Rectangle {
            id: sessionButtonBg

            color: config.SessionButtonColor
            radius: config.CornerRadius
            border.width: 0
            border.color: "transparent"
        }"""
content = content.replace(target, replacement)

target = """    Button {
        id: sessionButton

        height: inputHeight
        width: inputHeight
        hoverEnabled: true"""
replacement = """    Button {
        id: sessionButton

        height: inputHeight
        width: inputHeight
        hoverEnabled: true
        activeFocusOnTab: true"""
content = content.replace(target, replacement)

target = """        states: [
            State {
                name: "pressed\\\""""
replacement = """        states: [
            State {
                name: "focused"
                when: sessionButton.activeFocus
                PropertyChanges {
                    target: sessionButtonBg
                    color: Qt.darker(config.SessionButtonColor, 1.4)
                    border.width: 2
                    border.color: config.TextFieldHighlightColor || "white"
                }
            },
            State {
                name: "pressed\\\""""
content = content.replace(target, replacement)

target = """    Popup {
        id: sessionPopup

        width: inputWidth + padding * 2
        x: sessionButton.width + sessionList.spacing
        y: -(contentHeight + padding * 2) + sessionButton.height
        padding: 15"""
replacement = """    Popup {
        id: sessionPopup

        width: inputWidth + padding * 2
        x: sessionButton.width + sessionList.spacing
        y: -(contentHeight + padding * 2) + sessionButton.height
        padding: 15
        onOpened: {
            sessionList.forceActiveFocus()
        }"""
content = content.replace(target, replacement)

target = """        contentItem: ListView {
            id: sessionList

            implicitHeight: contentHeight
            spacing: 8
            model: sessionWrapper"""
replacement = """        contentItem: ListView {
            id: sessionList

            implicitHeight: contentHeight
            spacing: 8
            focus: true
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    sessionList.currentIndex = currentIndex
                    sessionPopup.close()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    sessionPopup.close()
                    event.accepted = true
                }
            }
            model: sessionWrapper"""
content = content.replace(target, replacement)

target = """            states: [
                State {
                    name: "hovered"
                    when: sessionEntry.hovered"""
replacement = """            states: [
                State {
                    name: "hovered"
                    when: sessionEntry.hovered || sessionEntry.highlighted"""
content = content.replace(target, replacement)
with open(file_path, "w") as f:
    f.write(content)

# 3. components/PowerPanel.qml
file_path = os.path.join(theme_path, "components/PowerPanel.qml")
with open(file_path, "r") as f:
    content = f.read()
target = """Item {
    implicitHeight: powerButton.height
    implicitWidth: powerButton.width"""
replacement = """Item {
    property alias powerButton: powerButton
    implicitHeight: powerButton.height
    implicitWidth: powerButton.width"""
content = content.replace(target, replacement)

target = """        background: Rectangle {
            id: powerButtonBg

            color: config.PowerButtonColor
            radius: config.CornerRadius
        }"""
replacement = """        background: Rectangle {
            id: powerButtonBg

            color: config.PowerButtonColor
            radius: config.CornerRadius
            border.width: 0
            border.color: "transparent"
        }"""
content = content.replace(target, replacement)

target = """    Button {
        id: powerButton

        height: inputHeight
        width: inputHeight
        hoverEnabled: true"""
replacement = """    Button {
        id: powerButton

        height: inputHeight
        width: inputHeight
        hoverEnabled: true
        activeFocusOnTab: true"""
content = content.replace(target, replacement)

target = """        states: [
            State {
                name: "pressed\\\""""
replacement = """        states: [
            State {
                name: "focused"
                when: powerButton.activeFocus
                PropertyChanges {
                    target: powerButtonBg
                    color: Qt.darker(config.PowerButtonColor, 1.4)
                    border.width: 2
                    border.color: config.TextFieldHighlightColor || "white"
                }
            },
            State {
                name: "pressed\\\""""
content = content.replace(target, replacement)

target = """    Popup {
        id: powerPopup

        height: inputHeight * 2.2 + padding * 2
        x: powerButton.width + powerList.spacing
        y: -height + powerButton.height
        padding: 15"""
replacement = """    Popup {
        id: powerPopup

        height: inputHeight * 2.2 + padding * 2
        x: powerButton.width + powerList.spacing
        y: -height + powerButton.height
        padding: 15
        onOpened: {
            powerList.forceActiveFocus()
        }"""
content = content.replace(target, replacement)

target = """        contentItem: ListView {
            id: powerList

            implicitWidth: contentWidth
            spacing: 8
            orientation: Qt.Horizontal
            clip: true

            model: powerModel"""
replacement = """        contentItem: ListView {
            id: powerList

            implicitWidth: contentWidth
            spacing: 8
            orientation: Qt.Horizontal
            clip: true
            focus: true
            Keys.onLeftPressed: decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    powerPopup.close()
                    var idx = currentIndex
                    if (idx == 0) sddm.suspend()
                    else if (idx == 1) sddm.reboot()
                    else sddm.powerOff()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    powerPopup.close()
                    event.accepted = true
                }
            }
            model: powerModel"""
content = content.replace(target, replacement)

target = """                states: [
                    State {
                        name: "hovered"
                        when: powerEntry.hovered"""
replacement = """                states: [
                    State {
                        name: "hovered"
                        when: powerEntry.hovered || powerEntry.highlighted"""
content = content.replace(target, replacement)
with open(file_path, "w") as f:
    f.write(content)

# 4. components/LoginPanel.qml
file_path = os.path.join(theme_path, "components/LoginPanel.qml")
with open(file_path, "r") as f:
    content = f.read()

target = """    property var inputWidth: Screen.width * config.LoginScale"""
replacement = """    property var inputWidth: Screen.width * config.LoginScale
 
    Component.onCompleted: {
        userPanel.usernameField.KeyNavigation.tab = passwordField;
        userPanel.usernameField.KeyNavigation.backtab = powerPanel.powerButton;
        passwordField.KeyNavigation.tab = loginButton;
        passwordField.KeyNavigation.backtab = userPanel.usernameField;
        loginButton.KeyNavigation.tab = sessionPanel.sessionButton;
        loginButton.KeyNavigation.backtab = passwordField;
        sessionPanel.sessionButton.KeyNavigation.tab = powerPanel.powerButton;
        sessionPanel.sessionButton.KeyNavigation.backtab = loginButton;
        powerPanel.powerButton.KeyNavigation.tab = userPanel.usernameField;
        powerPanel.powerButton.KeyNavigation.backtab = sessionPanel.sessionButton;
    }"""
content = content.replace(target, replacement)

target = """            background: Rectangle {
                id: buttonBackground

                color: config.LoginButtonBgColor
                opacity: 0.5
                radius: config.CornerRadius
            }"""
replacement = """            background: Rectangle {
                id: buttonBackground

                color: config.LoginButtonBgColor
                opacity: 0.5
                radius: config.CornerRadius
                border.width: 0
                border.color: "transparent"
            }"""
content = content.replace(target, replacement)

target = """        Button {
            id: loginButton

            height: inputHeight
            width: parent.width

            enabled: user != "" && password != "" ? true : false
            hoverEnabled: true"""
replacement = """        Button {
            id: loginButton

            height: inputHeight
            width: parent.width

            enabled: user != "" && password != "" ? true : false
            hoverEnabled: true
            activeFocusOnTab: true"""
content = content.replace(target, replacement)

target = """            states: [
                State {
                    name: "pressed\\\""""
replacement = """            states: [
                State {
                    name: "focused"
                    when: loginButton.activeFocus
                    PropertyChanges {
                        target: buttonBackground
                        color: Qt.darker(config.LoginButtonBgColor, 1.4)
                        opacity: 1
                        border.width: 2
                        border.color: config.TextFieldHighlightColor || "white"
                    }
                    PropertyChanges {
                        target: buttonText
                        opacity: 1
                    }
                },
                State {
                    name: "pressed\\\""""
content = content.replace(target, replacement)
with open(file_path, "w") as f:
    f.write(content)
'
    '';
  };

in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org/"
      # "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      # "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use LTS kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_6;
  # -------------------------------------------------------------------
  # KERNEL: Parámetros heredados de Fedora (GPU híbrida, Acer WMI)
  # -------------------------------------------------------------------
  # Bloquea nouveau (driver open-source) — usamos el driver propietario de NVIDIA
  boot.blacklistedKernelModules = [ "nouveau" "acer-wmi" ];
  # Parámetros extra del kernel (los mismos que usabas en Fedora)
  boot.kernelParams = [
    "acpi_enforce_resources=lax"     # Evita conflictos ACPI en Acer
    "lockdown=none"                  # Permite acceso a /dev/mem para modprobe nvidia
  ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  # Enable networking
  networking.networkmanager.enable = true;
  # Set your time zone.
  time.timeZone = "America/Guayaquil";
  # Select internationalisation properties.
  i18n.defaultLocale = "es_MX.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_EC.UTF-8";
    LC_IDENTIFICATION = "es_EC.UTF-8";
    LC_MEASUREMENT = "es_EC.UTF-8";
    LC_MONETARY = "es_EC.UTF-8";
    LC_NAME = "es_EC.UTF-8";
    LC_NUMERIC = "es_EC.UTF-8";
    LC_PAPER = "es_EC.UTF-8";
    LC_TELEPHONE = "es_EC.UTF-8";
    LC_TIME = "es_EC.UTF-8";
  };
  # -------------------------------------------------------------------
  # NVIDIA: Configuración híbrida Intel + RTX 4050 (MODO OFFLOAD)
  # -------------------------------------------------------------------
  # Habilitamos el driver propietario de NVIDIA
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Modesetting necesario para Wayland
    modesetting.enable = true;
    # Gestión de energía (suspende la GPU cuando no se usa)
    powerManagement.enable = true;
    # Apagado total de la GPU en modo híbrido (arquitectura Turing/Ada Lovelace+)
    powerManagement.finegrained = true;
    # Driver propietario (NO open-source)
    open = false;
    # Panel de control de NVIDIA (nvidia-settings)
    nvidiaSettings = true;
    # Versión del driver (estable)
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # PRIME Offload: NVIDIA solo se activa bajo demanda
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";    # Intel Raptor Lake-P UHD Graphics
      nvidiaBusId = "PCI:1:0:0";   # NVIDIA RTX 4050 Max-Q
    };
  };
  # Paquetes VA-API y Vulkan para decodificación de video
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver       # VA-API Intel (antes vaapiIntel)
      libva-vdpau-driver       # Traducción VDPAU → VA-API (antes vaapiVdpau)
      libvdpau-va-gl           # VDPAU con backend VA-API/OpenGL
      nvidia-vaapi-driver      # VA-API para NVIDIA
    ];
  };
  # Enable the X11 windowing system (necesario para GDM y XWayland).
  services.xserver.enable = true;
  # -------------------------------------------------------------------
  # GDM como display manager (sin GNOME — usamos Hyprland)
  # -------------------------------------------------------------------
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.theme = "catppuccin-sddm-corners";
  services.displayManager.sddm.extraPackages = with pkgs.kdePackages; [
    qt5compat
    qtmultimedia
    qtsvg
  ];



  services.accounts-daemon.enable = true;
  services.displayManager.defaultSession = "hyprland";
  # GNOME está deshabilitado; solo usamos GDM para iniciar sesión
  services.desktopManager.gnome.enable = false;
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "latam";
    variant = "";
  };
  # Configure console keymap
  console.keyMap = "la-latin1";
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson-escpr2 ];
  };
  # Enable Avahi for network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  # Enable scanner support
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.epsonscan2 ];
  };

  # Define a user account. Don't forget to set a password with `passwd'.
  users.users.josue = {
    isNormalUser = true;
    description = "josue";
    extraGroups = [ "networkmanager" "wheel" "docker" "lp" "scanner" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
    #  thunderbird
    ];
  };
  # Install firefox.
  programs.firefox.enable = true;
  programs.dconf.enable = true;
  # Allow unfree packages (Spotify, Steam, VSCode, Obsidian, NVIDIA drivers)
  nixpkgs.config.allowUnfree = true;
  # -------------------------------------------------------------------
  # HYPRLAND: Window Manager principal + portal para apps Flatpak
  # -------------------------------------------------------------------
  programs.hyprland = {
    withUWSM = true;
    enable = true;
    xwayland.enable = true;     # Para apps que no soportan Wayland (Steam, Wine, etc.)
  };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    config.common.default = "*";
  };
  # -------------------------------------------------------------------
  # PAQUETES DEL SISTEMA: Tu entorno completo (migrado de Fedora 43)
  # -------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    custom-sddm-theme
    # hypr-dynamic-cursors-plugin
    imagemagick
    cava
    adwaita-icon-theme
    # --- Editores de texto / IDE ---
    neovim# Editor principal
    vim                             # Editor secundario
    vscode# Visual Studio Code
    # --- Navegadores ---
    (brave.override {
      commandLineArgs = [
        "--ozone-platform-hint=auto"
        "--enable-features=WaylandWindowDecorations"
        "--use-gl=egl"
      ];
    }) # Navegador principal
    kooha
    # --- Terminales ---
    warp-terminal                   # Terminal principal
    ghostty                         # Ghostty (alternativa)
    # --- Runtimes y Compiladores ---
    gcc                             # Compilador C/C++
    gnumake                         # Make
    cmake                           # CMake (hyprland-plugins, etc.)
    pkg-config                      # pkg-config
    binutils                        # Herramientas binarias: ld, as, objdump
    nodejs                          # Node.js
    bun                             # Bun runtime (opencode-ai)
    pnpm                            # Gestor de paquetes JS
    dotnet-sdk_8                    # .NET SDK 8.0
    jdk17                           # Java 17 OpenJDK
    spark                           # Apache Spark
    rustup                          # Rust toolchain manager
    go                              # Go compiler
    gopls                           # Go language server
    # --- Python 3 + paquetes (para tus widgets y desarrollo) ---
    hyprPython                      # python3 with psutil, pygobject3, pandas, etc.
    hyprPythonWrapped               # command 'hypr-python' = python3 + GI_TYPELIB_PATH
    # --- Python: paquetes SIN equivalente directo en nixpkgs ---
    # Instálalos manualmente con: pip install --user <paquete>
    #   • deep-translator, scholarly, google-genai, pdfplumber, PyMuPDF, selenium, ollama
    # --- Control de versiones ---
    git
    gh
    git-lfs
    # --- Red, descargas y archivos ---
    direnv                          # Carga variables de entorno por directorio
    nix-direnv                      # Integración rápida de nix con direnv
    fzf                             # Fuzzy finder para la terminal
    yazi                            # File manager
    ffmpegthumbnailer               # Video thumbnails generator for yazi
    poppler-utils                   # PDF preview utilities (pdftoppm) for yazi
    curl
    wget
    unzip
    p7zip
    jq
    ntfs3g
    xdg-utils
    # --- Monitoreo del sistema ---
    btop
    htop
    eza                             # Un reemplazo moderno para 'ls'
    fastfetch
    lshw
    pciutils
    nvtopPackages.nvidia
    # --- AI / Machine Learning ---
    ollama                          # Ollama CLI
    antigravity                     # Antigravity CLI
    cudatoolkit                     # CUDA Toolkit (nvcc, etc.)
    # --- Bluetooth ---
    blueman
    # --- Multimedia ---
    vlc
    mpv
    ffmpeg
    easyeffects
    (pkgs.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-vaapi
        obs-vkcapture
        obs-pipewire-audio-capture
        obs-gstreamer
        obs-multi-rtmp
        obs-backgroundremoval
      ];
    })
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    # --- Audio (control desde terminal / scripts) ---
    playerctl
    pamixer
    pavucontrol                     # Mixer gráfico (se abre desde waybar)
    # --- Brillo y temperatura de color ---
    brightnessctl
    gammastep
    # --- Ofimática ---
    libreoffice
    onlyoffice-desktopeditors
    # --- Correo ---
    thunderbird
    # --- Apps de escritorio ---
    spotify
    pear-desktop                    # YouTube Music (Electron wrapper)
    obsidian
    qbittorrent
    gparted
    discord

    #Latex
    texlive.combined.scheme-full
    texstudio

    # ===================================================================
    # HYPRLAND ECOSYSTEM: Wayland composables
    # ===================================================================
    # --- Barra superior ---
    waybar
    # --- Centro de notificaciones ---
    swaynotificationcenter
    # --- Lanzador (Super + Space) ---
    wofi
    nwg-drawer
    # --- Fondo de pantalla ---
    hyprpaper
    wallust
    awww
    # --- Screenshots (Super + Shift + S) ---
    grimblast
    # --- Herramientas Wayland ---
    wl-clipboard                    # Portapapeles (wl-copy, wl-paste)
    cliphist                        # Historial de portapapeles (Super + V)
    libnotify                       # notify-send (notificaciones desde scripts)
    networkmanagerapplet            # Applet de red en la bandeja
    # --- Widgets Python — dependencias nativas (GI typelibs) ---
    # giTypelibs es un symlinkJoin de todas las librerías GI (definido arriba)
    giTypelibs
    # --- Explorador de archivos ---
    nautilus                        # Archivos (Super + E)
    # --- Configuración del sistema (accesible desde swaync) ---
    gnome-control-center            # Panel de control estilo GNOME
    # --- Gaming ---
    gamescope                       # Compositor para juegos (menos input lag)
    prismlauncher                   # Launcher de Minecraft (fork de MultiMC)
    # --- Utilidades ---
    gnome-disk-utility              # Discos
    file-roller                     # Archivador gráfico
    system-config-printer           # Gestión de impresoras
    simple-scan                     # Escaneo simple
    epsonscan2                      # App de Epson para escaneo
    starship                        # Prompts personalizables para shell

    # Aplicaciones multimedia y documentos básicas
    evince
    eog
    gedit

  ];
  # -------------------------------------------------------------------
  # ALIAS DE SISTEMA: Tu panel de control
  # -------------------------------------------------------------------
  environment.shellAliases = {
    nix-apply = "pushd /etc/nixos && sudo git add . && sudo nixos-rebuild switch --flake .#nixos && popd";
    nix-edit = "sudo nvim /etc/nixos/configuration.nix";
    nix-clean = "sudo nix-collect-garbage -d";

    # Eza (ls replacement)
    ls = "eza --icons";
    ll = "eza -lh --icons --grid --group-directories-first --color=always";
    la = "eza -a --icons --group-directories-first --color=always";
    lt = "eza --tree --icons --color=always";
  };
  # PATH adicional para binarios de usuario
  environment.variables = {
    PATH = [
      "$HOME/.local/bin"
      "$HOME/.bun/bin"
      "$HOME/.npm-global/bin"
    ];
  };
  # Variables disponibles en la sesión Wayland (no solo en shells)
  environment.sessionVariables = {
    GI_TYPELIB_PATH = "${giTypelibs}/lib/girepository-1.0";
    # --- EDITOR POR DEFECTO ---
    EDITOR = "nvim";
    VISUAL = "nvim";
    # --- LS_COLORS para Gruvbox ---
    LS_COLORS = "bd=38;5;214;48;5;235:cd=38;5;214;48;5;235:di=38;5;108:ex=38;5;142:fi=38;5;223:ln=38;5;109:mi=38;5;167:or=38;5;167;48;5;235:pi=38;5;214;48;5;235:so=38;5;175:do=38;5;175:sg=38;5;235;48;5;214:su=38;5;235;48;5;167:tw=38;5;235;48;5;108:ow=38;5;108;48;5;235:st=38;5;235;48;5;109:*.tar=38;5;167:*.tgz=38;5;167:*.zip=38;5;167:*.gz=38;5;167:*.bz2=38;5;167:*.7z=38;5;167:*.jpg=38;5;175:*.jpeg=38;5;175:*.png=38;5;175:*.gif=38;5;175:*.mp3=38;5;109:*.wav=38;5;109:*.flac=38;5;109:*.mp4=38;5;175:*.mkv=38;5;175:";
    # --- NVIDIA Hyprland FIXES ---
    # LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1"; # Para apps Electron en Wayland

  };
  # Puente para binarios que dependen de FHS (bun, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];
  # -------------------------------------------------------------------
  # DISCOS: Montaje automático de particiones NTFS
  # -------------------------------------------------------------------
  fileSystems."/mnt/Nuevo_vol" = {
    device = "/dev/disk/by-uuid/280A1A360A1A018C";
    fsType = "ntfs3";
    options = [ "rw" "uid=1000" "nofail" "x-gvfs-show" "force" ];
  };

  fileSystems."/mnt/New_Volume" = {
    device = "/dev/disk/by-uuid/2A02FCDB02FCACC7";
    fsType = "ntfs3";
    options = [ "rw" "uid=1000" "nofail" "x-gvfs-show" "force" ];
  };

  fileSystems."/mnt/Windows_XLite" = {
    device = "/dev/disk/by-uuid/D29A9F5A9A9F3A45";
    fsType = "ntfs3";
    options = [ "rw" "uid=1000" "nofail" "x-gvfs-show" "force" ];
  };

  # Configuración para que udisks2 (Nautilus) monte discos externos NTFS con 'force'
  environment.etc."udisks2/mount_options.conf" = {
    text = ''
      [defaults]
      ntfs_defaults=uid=$UID,gid=$GID,force
      ntfs_allow=uid=$UID,gid=$GID,umask,dmask,fmask,locale,norecover,ignore_case,compression,nocompression,show_sys_files,hide_dot_files,windows_names,lowntfs-3g,force
      ntfs_drivers=ntfs3,ntfs
      ntfs:ntfs3_defaults=uid=$UID,gid=$GID,force,prealloc
      ntfs:ntfs3_allow=uid=$UID,gid=$GID,umask,dmask,fmask,force,prealloc
    '';
  };

  # Servicios para que los discos aparezcan en Nautilus y se puedan gestionar
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # -------------------------------------------------------------------
  # SERVICIOS: Demonios que corren en segundo plano
  # -------------------------------------------------------------------
  # --- Bluetooth ---
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
    };
  };
  # --- Docker ---
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    "bip" = "10.10.0.1/24";
    "default-address-pools" = [
      {
        "base" = "10.10.1.0/24";
        "size" = 24;
      }
    ];
  };
  # --- Flatpak (Zoom, Postman, Minecraft, IntelliJ, etc.) ---
  services.flatpak.enable = true;
  # --- Gestión de Energía y Temperatura ---
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  # --- Tailscale ---
  #services.tailscale.enable = true;
  # --- OpenSSH ---
  services.openssh.enable = true;
  # --- Ollama (AI server) ---
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;    # Use RTX 4050 with CUDA
  };
  # --- Nerd Fonts (íconos para waybar, widgets, terminales) ---
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
  ];
  # -------------------------------------------------------------------
  # UDEV: Hotplug GPU — cambia clocks y cursor al conectar/desconectar HDMI
  # -------------------------------------------------------------------
  services.udev.extraRules = ''
    # Disparado por el kernel cuando cambia el estado de un puerto DRM (HDMI)
    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", \
      RUN+="${pkgs.bash}/bin/bash /home/josue/.config/hypr/scripts/auto-gpu.sh"
  '';
  # -------------------------------------------------------------------
  # PROGRAMAS con configuración a nivel sistema
  # -------------------------------------------------------------------
  # --- Steam + Juegos ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  # Habilita reglas de udev para mandos (Steam Controller, DualShock, DualSense, etc.)
  hardware.steam-hardware.enable = true;
  # --- GPG para firmar commits de git ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  # --- ZSH: Shell principal ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
  # Habilitar direnv y su integración con nix
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  # Habilitar fzf y su integración con la shell
  programs.fzf = {
    fuzzyCompletion = true;
    keybindings = true;
  };

  # Habilitar LocalSend y abrir puertos en el firewall automáticamente
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  
  # Permitir cambiar el fondo de SDDM sin contraseña para el script de wallpaper
  security.sudo.extraRules = [{
    users = [ "josue" ];
    commands = [
      { command = "/run/current-system/sw/bin/cp /tmp/sddm-background.png /var/lib/sddm/background.png"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/chmod 644 /var/lib/sddm/background.png"; options = [ "NOPASSWD" ]; }
    ];
  }];

  # -------------------------------------------------------------------
  # CONFIGURACIÓN DE NVCHAD PARA ROOT
  # -------------------------------------------------------------------
  # Esto crea enlaces simbólicos para que 'sudo nvim' use la misma config de 'josue'
  system.activationScripts.nvim-root-config = {
    text = ''
      mkdir -p /root/.config /root/.local/share /root/.local/state
      ln -sfn /home/josue/.config/nvim /root/.config/nvim
      ln -sfn /home/josue/.local/share/nvim /root/.local/share/nvim
      ln -sfn /home/josue/.local/state/nvim /root/.local/state/nvim
    '';
  };

  system.stateVersion = "25.11"; # Did you read the comment?
}
