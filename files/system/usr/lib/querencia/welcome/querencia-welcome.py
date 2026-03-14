#!/usr/bin/python3
# -*- coding: utf-8 -*-
# =============================================================================
# Querencia Linux — Welcome Center
# "Where Linux Feels at Home"
#
# A MATE Desktop-specific welcome application with full i18n support.
# Inspired by Linux Mint's mintwelcome, completely rewritten for
# Querencia Linux — an atomic/immutable desktop based on AlmaLinux 10.
#
# Dependencies: Python 3, GTK 3.0 (gi) — no external packages.
#
# Supported languages (matching glibc-langpack-* in the image):
#   en, de, fr, es, it, pt, nl, pl, ru, ja, zh, ko
#
# Translation workflow:
#   1. All user-visible strings use _("English text")
#   2. Translations are embedded in TRANSLATIONS dict (no .po/.mo files needed)
#   3. The app reads LC_MESSAGES / LANG at startup to pick the right language
#   4. Falls back to English for any missing translation
#
# MATE-specific details:
#   - Uses MATE tools: mate-appearance-properties, mate-control-center,
#     mate-terminal, mate-about, mate-screenshot, caja
#   - References MATE concepts: Caja (file manager), Marco (window manager),
#     Pluma (text editor), Engrampa (archive manager)
#   - Uses MATE panel terminology and BlueMenta theme
#   - Icons from the menta icon theme (MATE default on Querencia)
# =============================================================================

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")

import gettext
import json
import locale
import os
import platform
import subprocess
import sys

from gi.repository import Gdk, Gio, GLib, Gtk, Pango

# =============================================================================
# i18n Setup
# =============================================================================

# Detect system language — use first 2 chars (e.g. "de" from "de_DE.UTF-8")
def _detect_lang():
    """Detect the current UI language from the environment."""
    for var in ("LC_MESSAGES", "LC_ALL", "LANG", "LANGUAGE"):
        val = os.environ.get(var, "")
        if val and val not in ("C", "POSIX"):
            # Handle LANGUAGE which can be colon-separated
            lang = val.split(":")[0].split(".")[0].split("_")[0].lower()
            if lang and len(lang) >= 2:
                return lang[:2]
    return "en"


CURRENT_LANG = _detect_lang()

# =============================================================================
# Embedded Translations
# =============================================================================
# Keys are English strings (used as fallback). Values are dicts of lang→translation.
# Only non-English translations are listed. If a language is missing for a string,
# the English original is used.
#
# Note: These are human-quality translations, not machine translations.
# Some technical terms (Flatpak, Micromamba, Distrobox, bootc, ujust) are
# intentionally left untranslated as they are proper nouns / CLI commands.

TRANSLATIONS = {
    # ---- Window / HeaderBar ----
    "Welcome to Querencia Linux": {
        "de": "Willkommen bei Querencia Linux",
        "fr": "Bienvenue sur Querencia Linux",
        "es": "Bienvenido a Querencia Linux",
        "it": "Benvenuto in Querencia Linux",
        "pt": "Bem-vindo ao Querencia Linux",
        "nl": "Welkom bij Querencia Linux",
        "pl": "Witamy w Querencia Linux",
        "ru": "Добро пожаловать в Querencia Linux",
        "ja": "Querencia Linux へようこそ",
        "zh": "欢迎使用 Querencia Linux",
        "ko": "Querencia Linux에 오신 것을 환영합니다",
    },
    "Where Linux Feels at Home": {
        "de": "Wo sich Linux wie zu Hause anfühlt",
        "fr": "Là où Linux se sent chez soi",
        "es": "Donde Linux se siente en casa",
        "it": "Dove Linux si sente a casa",
        "pt": "Onde o Linux se sente em casa",
        "nl": "Waar Linux thuiskomt",
        "pl": "Gdzie Linux czuje się jak w domu",
        "ru": "Где Linux чувствует себя как дома",
        "ja": "Linux がくつろげる場所",
        "zh": "Linux 有家的感觉",
        "ko": "Linux가 편안함을 느끼는 곳",
    },
    # ---- Sidebar labels ----
    "Welcome": {
        "de": "Willkommen",
        "fr": "Bienvenue",
        "es": "Bienvenida",
        "it": "Benvenuto",
        "pt": "Bem-vindo",
        "nl": "Welkom",
        "pl": "Witaj",
        "ru": "Добро пожаловать",
        "ja": "ようこそ",
        "zh": "欢迎",
        "ko": "환영합니다",
    },
    "First Steps": {
        "de": "Erste Schritte",
        "fr": "Premiers pas",
        "es": "Primeros pasos",
        "it": "Primi passi",
        "pt": "Primeiros passos",
        "nl": "Eerste stappen",
        "pl": "Pierwsze kroki",
        "ru": "Первые шаги",
        "ja": "はじめに",
        "zh": "第一步",
        "ko": "시작하기",
    },
    "Installing Software": {
        "de": "Software installieren",
        "fr": "Installer des logiciels",
        "es": "Instalar software",
        "it": "Installare software",
        "pt": "Instalar software",
        "nl": "Software installeren",
        "pl": "Instalowanie oprogramowania",
        "ru": "Установка программ",
        "ja": "ソフトウェアのインストール",
        "zh": "安装软件",
        "ko": "소프트웨어 설치",
    },
    "System Info": {
        "de": "Systeminformationen",
        "fr": "Informations système",
        "es": "Información del sistema",
        "it": "Informazioni di sistema",
        "pt": "Informações do sistema",
        "nl": "Systeeminformatie",
        "pl": "Informacje o systemie",
        "ru": "Информация о системе",
        "ja": "システム情報",
        "zh": "系统信息",
        "ko": "시스템 정보",
    },
    "Help & Links": {
        "de": "Hilfe & Links",
        "fr": "Aide et liens",
        "es": "Ayuda y enlaces",
        "it": "Aiuto e link",
        "pt": "Ajuda e links",
        "nl": "Hulp & links",
        "pl": "Pomoc i linki",
        "ru": "Помощь и ссылки",
        "ja": "ヘルプとリンク",
        "zh": "帮助与链接",
        "ko": "도움말 및 링크",
    },
    # ---- Welcome page ----
    "Querencia Linux is an atomic, immutable desktop built on AlmaLinux 10 "
    "with the MATE Desktop Environment. Your system updates itself as a whole "
    "image — safe, reliable, and always rollback-ready.": {
        "de": "Querencia Linux ist ein atomarer, unveränderlicher Desktop auf Basis von "
              "AlmaLinux 10 mit der MATE-Desktopumgebung. Ihr System aktualisiert sich als "
              "komplettes Image — sicher, zuverlässig und jederzeit rücksetzbar.",
        "fr": "Querencia Linux est un bureau atomique et immuable basé sur AlmaLinux 10 "
              "avec l'environnement de bureau MATE. Votre système se met à jour comme une "
              "image complète — sûr, fiable et toujours prêt à être restauré.",
        "es": "Querencia Linux es un escritorio atómico e inmutable basado en AlmaLinux 10 "
              "con el entorno de escritorio MATE. Su sistema se actualiza como una imagen "
              "completa — seguro, fiable y siempre reversible.",
        "it": "Querencia Linux è un desktop atomico e immutabile basato su AlmaLinux 10 "
              "con l'ambiente desktop MATE. Il sistema si aggiorna come immagine completa "
              "— sicuro, affidabile e sempre ripristinabile.",
        "pt": "O Querencia Linux é um desktop atómico e imutável baseado no AlmaLinux 10 "
              "com o ambiente de desktop MATE. O seu sistema atualiza-se como uma imagem "
              "completa — seguro, fiável e sempre reversível.",
        "nl": "Querencia Linux is een atomair, onveranderlijk bureaublad gebaseerd op "
              "AlmaLinux 10 met de MATE-desktopomgeving. Uw systeem werkt zichzelf bij als "
              "compleet image — veilig, betrouwbaar en altijd terug te draaien.",
        "pl": "Querencia Linux to atomowy, niezmienny pulpit oparty na AlmaLinux 10 "
              "ze środowiskiem MATE. System aktualizuje się jako cały obraz — bezpiecznie, "
              "niezawodnie i zawsze z możliwością cofnięcia zmian.",
        "ru": "Querencia Linux — это атомарный неизменяемый рабочий стол на базе AlmaLinux 10 "
              "с окружением MATE. Система обновляется как целый образ — безопасно, надёжно "
              "и всегда с возможностью отката.",
        "ja": "Querencia Linux は AlmaLinux 10 と MATE デスクトップ環境をベースにした "
              "アトミックで不変のデスクトップです。システムはイメージ全体として更新されます "
              "— 安全で信頼性が高く、いつでもロールバックできます。",
        "zh": "Querencia Linux 是基于 AlmaLinux 10 和 MATE 桌面环境构建的原子化不可变桌面。"
              "系统以完整镜像方式自动更新 — 安全、可靠，随时可以回滚。",
        "ko": "Querencia Linux는 AlmaLinux 10과 MATE 데스크톱 환경을 기반으로 한 "
              "원자적이고 불변인 데스크톱입니다. 시스템은 전체 이미지로 업데이트됩니다 "
              "— 안전하고 신뢰할 수 있으며, 언제든 롤백할 수 있습니다.",
    },
    "Let's get started!": {
        "de": "Los geht's!",
        "fr": "C'est parti !",
        "es": "¡Empecemos!",
        "it": "Iniziamo!",
        "pt": "Vamos começar!",
        "nl": "Aan de slag!",
        "pl": "Zaczynajmy!",
        "ru": "Начнём!",
        "ja": "はじめましょう！",
        "zh": "开始吧！",
        "ko": "시작합시다!",
    },
    # ---- First Steps page ----
    "Get familiar with your MATE Desktop. Click \"Open\" to launch each tool.": {
        "de": "Lernen Sie Ihren MATE-Desktop kennen. Klicken Sie auf \"Öffnen\", um jedes Werkzeug zu starten.",
        "fr": "Familiarisez-vous avec votre bureau MATE. Cliquez sur « Ouvrir » pour lancer chaque outil.",
        "es": "Familiarícese con su escritorio MATE. Haga clic en \"Abrir\" para iniciar cada herramienta.",
        "it": "Familiarizza con il tuo desktop MATE. Fai clic su \"Apri\" per avviare ogni strumento.",
        "pt": "Familiarize-se com o seu ambiente MATE. Clique em \"Abrir\" para iniciar cada ferramenta.",
        "nl": "Maak kennis met uw MATE-bureaublad. Klik op \"Openen\" om elk hulpmiddel te starten.",
        "pl": "Poznaj swoje środowisko MATE. Kliknij \"Otwórz\", aby uruchomić każde narzędzie.",
        "ru": "Познакомьтесь с рабочим столом MATE. Нажмите «Открыть», чтобы запустить каждый инструмент.",
        "ja": "MATE デスクトップに慣れましょう。「開く」をクリックして各ツールを起動します。",
        "zh": "熟悉您的 MATE 桌面。点击"打开"启动各个工具。",
        "ko": "MATE 데스크톱을 살펴보세요. \"열기\"를 클릭하여 각 도구를 실행합니다.",
    },
    "Open": {
        "de": "Öffnen",
        "fr": "Ouvrir",
        "es": "Abrir",
        "it": "Apri",
        "pt": "Abrir",
        "nl": "Openen",
        "pl": "Otwórz",
        "ru": "Открыть",
        "ja": "開く",
        "zh": "打开",
        "ko": "열기",
    },
    # -- First Steps: Appearance --
    "Appearance": {
        "de": "Erscheinungsbild",
        "fr": "Apparence",
        "es": "Apariencia",
        "it": "Aspetto",
        "pt": "Aparência",
        "nl": "Uiterlijk",
        "pl": "Wygląd",
        "ru": "Внешний вид",
        "ja": "外観",
        "zh": "外观",
        "ko": "모양새",
    },
    "Customize your MATE Desktop theme, icons, and fonts. "
    "Querencia comes with the BlueMenta theme, Noto fonts, "
    "and the Adwaita cursor.": {
        "de": "Passen Sie das Theme, die Symbole und Schriften Ihres MATE-Desktops an. "
              "Querencia wird mit dem BlueMenta-Theme, Noto-Schriften und dem Adwaita-Cursor ausgeliefert.",
        "fr": "Personnalisez le thème, les icônes et les polices de votre bureau MATE. "
              "Querencia est livré avec le thème BlueMenta, les polices Noto et le curseur Adwaita.",
        "es": "Personalice el tema, los iconos y las fuentes de su escritorio MATE. "
              "Querencia incluye el tema BlueMenta, las fuentes Noto y el cursor Adwaita.",
        "it": "Personalizza il tema, le icone e i caratteri del tuo desktop MATE. "
              "Querencia include il tema BlueMenta, i font Noto e il cursore Adwaita.",
        "pt": "Personalize o tema, os ícones e as fontes do seu ambiente MATE. "
              "O Querencia vem com o tema BlueMenta, fontes Noto e o cursor Adwaita.",
        "nl": "Pas het thema, de pictogrammen en lettertypen van uw MATE-bureaublad aan. "
              "Querencia wordt geleverd met het BlueMenta-thema, Noto-lettertypen en de Adwaita-cursor.",
        "pl": "Dostosuj motyw, ikony i czcionki pulpitu MATE. "
              "Querencia zawiera motyw BlueMenta, czcionki Noto i kursor Adwaita.",
        "ru": "Настройте тему, значки и шрифты рабочего стола MATE. "
              "Querencia поставляется с темой BlueMenta, шрифтами Noto и курсором Adwaita.",
        "ja": "MATE デスクトップのテーマ、アイコン、フォントをカスタマイズできます。"
              "Querencia には BlueMenta テーマ、Noto フォント、Adwaita カーソルが含まれています。",
        "zh": "自定义 MATE 桌面的主题、图标和字体。"
              "Querencia 预装了 BlueMenta 主题、Noto 字体和 Adwaita 光标。",
        "ko": "MATE 데스크톱의 테마, 아이콘, 글꼴을 사용자 정의하세요. "
              "Querencia에는 BlueMenta 테마, Noto 글꼴, Adwaita 커서가 포함되어 있습니다.",
    },
    # -- First Steps: App Store --
    "App Store (Warehouse)": {
        "de": "App Store (Warehouse)",
        "fr": "Magasin d'applications (Warehouse)",
        "es": "Tienda de aplicaciones (Warehouse)",
        "it": "Negozio di app (Warehouse)",
        "pt": "Loja de aplicações (Warehouse)",
        "nl": "App Store (Warehouse)",
        "pl": "Sklep z aplikacjami (Warehouse)",
        "ru": "Магазин приложений (Warehouse)",
        "ja": "アプリストア（Warehouse）",
        "zh": "应用商店（Warehouse）",
        "ko": "앱 스토어 (Warehouse)",
    },
    "Browse and install apps from Flathub using Warehouse. "
    "On an atomic system like Querencia, all desktop apps are Flatpaks — "
    "sandboxed and independent of the base system.": {
        "de": "Durchstöbern und installieren Sie Apps von Flathub mit Warehouse. "
              "Auf einem atomaren System wie Querencia sind alle Desktop-Apps Flatpaks — "
              "isoliert und unabhängig vom Grundsystem.",
        "fr": "Parcourez et installez des applications depuis Flathub avec Warehouse. "
              "Sur un système atomique comme Querencia, toutes les applications de bureau "
              "sont des Flatpaks — isolées et indépendantes du système de base.",
        "es": "Explore e instale aplicaciones de Flathub con Warehouse. "
              "En un sistema atómico como Querencia, todas las aplicaciones de escritorio "
              "son Flatpaks — aisladas e independientes del sistema base.",
        "it": "Sfoglia e installa app da Flathub con Warehouse. "
              "Su un sistema atomico come Querencia, tutte le app desktop sono Flatpak — "
              "isolate e indipendenti dal sistema base.",
        "pt": "Explore e instale aplicações do Flathub com o Warehouse. "
              "Num sistema atómico como o Querencia, todas as aplicações são Flatpaks — "
              "isoladas e independentes do sistema base.",
        "nl": "Blader door en installeer apps van Flathub met Warehouse. "
              "Op een atomair systeem als Querencia zijn alle desktopapps Flatpaks — "
              "geïsoleerd en onafhankelijk van het basissysteem.",
        "pl": "Przeglądaj i instaluj aplikacje z Flathub za pomocą Warehouse. "
              "Na systemie atomowym jak Querencia wszystkie aplikacje to Flatpaki — "
              "izolowane i niezależne od systemu bazowego.",
        "ru": "Просматривайте и устанавливайте приложения из Flathub через Warehouse. "
              "В атомарной системе как Querencia все приложения — это Flatpak-пакеты, "
              "изолированные и независимые от базовой системы.",
        "ja": "Warehouse を使って Flathub からアプリを閲覧・インストールできます。"
              "Querencia のようなアトミックシステムでは、すべてのデスクトップアプリは "
              "Flatpak です — サンドボックス化され、ベースシステムから独立しています。",
        "zh": "使用 Warehouse 浏览和安装 Flathub 上的应用。"
              "在 Querencia 这样的原子化系统上，所有桌面应用都是 Flatpak — "
              "沙盒化且独立于基础系统。",
        "ko": "Warehouse를 사용하여 Flathub에서 앱을 탐색하고 설치하세요. "
              "Querencia와 같은 원자적 시스템에서 모든 데스크톱 앱은 Flatpak이며 "
              "— 샌드박스로 격리되어 기본 시스템과 독립적입니다.",
    },
    # -- First Steps: System Settings (MATE Control Center) --
    "MATE Control Center": {
        "de": "MATE-Einstellungen",
        "fr": "Centre de contrôle MATE",
        "es": "Centro de control de MATE",
        "it": "Centro di controllo MATE",
        "pt": "Centro de controlo do MATE",
        "nl": "MATE-configuratiecentrum",
        "pl": "Centrum sterowania MATE",
        "ru": "Центр управления MATE",
        "ja": "MATE コントロールセンター",
        "zh": "MATE 控制中心",
        "ko": "MATE 제어 센터",
    },
    "Configure displays, keyboard layouts, mouse, network, "
    "default applications, and more. This is the central settings "
    "hub for the MATE Desktop.": {
        "de": "Konfigurieren Sie Bildschirme, Tastaturlayouts, Maus, Netzwerk, "
              "Standardanwendungen und mehr. Dies ist die zentrale Einstellungszentrale "
              "der MATE-Desktopumgebung.",
        "fr": "Configurez les écrans, dispositions de clavier, souris, réseau, "
              "applications par défaut et plus. C'est le centre de configuration "
              "de l'environnement de bureau MATE.",
        "es": "Configure pantallas, disposiciones de teclado, ratón, red, "
              "aplicaciones predeterminadas y más. Este es el centro de configuración "
              "del escritorio MATE.",
        "it": "Configura schermi, layout di tastiera, mouse, rete, "
              "applicazioni predefinite e altro. Questo è il centro impostazioni "
              "dell'ambiente desktop MATE.",
        "pt": "Configure ecrãs, disposições de teclado, rato, rede, "
              "aplicações predefinidas e mais. Este é o centro de configuração "
              "do ambiente de trabalho MATE.",
        "nl": "Configureer beeldschermen, toetsenbordindelingen, muis, netwerk, "
              "standaardtoepassingen en meer. Dit is het centrale instellingencentrum "
              "van de MATE-desktopomgeving.",
        "pl": "Skonfiguruj wyświetlacze, układy klawiatury, mysz, sieć, "
              "domyślne aplikacje i więcej. To centralne centrum ustawień "
              "środowiska MATE.",
        "ru": "Настройте дисплеи, раскладки клавиатуры, мышь, сеть, "
              "приложения по умолчанию и многое другое. Это центр настроек "
              "рабочего стола MATE.",
        "ja": "ディスプレイ、キーボードレイアウト、マウス、ネットワーク、"
              "デフォルトアプリケーションなどを設定できます。MATE デスクトップの"
              "中央設定ハブです。",
        "zh": "配置显示器、键盘布局、鼠标、网络、默认应用程序等。"
              "这是 MATE 桌面环境的中央设置中心。",
        "ko": "디스플레이, 키보드 레이아웃, 마우스, 네트워크, "
              "기본 응용 프로그램 등을 구성합니다. MATE 데스크톱의 "
              "중앙 설정 허브입니다.",
    },
    # -- First Steps: File Manager (Caja) --
    "File Manager (Caja)": {
        "de": "Dateimanager (Caja)",
        "fr": "Gestionnaire de fichiers (Caja)",
        "es": "Gestor de archivos (Caja)",
        "it": "Gestore file (Caja)",
        "pt": "Gestor de ficheiros (Caja)",
        "nl": "Bestandsbeheer (Caja)",
        "pl": "Menedżer plików (Caja)",
        "ru": "Файловый менеджер (Caja)",
        "ja": "ファイルマネージャー（Caja）",
        "zh": "文件管理器（Caja）",
        "ko": "파일 관리자 (Caja)",
    },
    "Caja is the MATE file manager. Browse your files, "
    "manage bookmarks, and connect to network shares. "
    "It supports tabs, split view, and file previews.": {
        "de": "Caja ist der MATE-Dateimanager. Durchsuchen Sie Ihre Dateien, "
              "verwalten Sie Lesezeichen und verbinden Sie sich mit Netzwerkfreigaben. "
              "Er unterstützt Tabs, geteilte Ansicht und Dateivorschau.",
        "fr": "Caja est le gestionnaire de fichiers MATE. Parcourez vos fichiers, "
              "gérez les signets et connectez-vous aux partages réseau. "
              "Il prend en charge les onglets, la vue divisée et les aperçus.",
        "es": "Caja es el gestor de archivos de MATE. Explore sus archivos, "
              "gestione marcadores y conéctese a recursos compartidos en red. "
              "Soporta pestañas, vista dividida y vista previa de archivos.",
        "it": "Caja è il file manager di MATE. Sfoglia i tuoi file, "
              "gestisci i segnalibri e connettiti alle condivisioni di rete. "
              "Supporta schede, vista divisa e anteprime dei file.",
        "pt": "O Caja é o gestor de ficheiros do MATE. Navegue pelos seus ficheiros, "
              "gerencie favoritos e conecte-se a partilhas de rede. "
              "Suporta separadores, vista dividida e pré-visualização de ficheiros.",
        "nl": "Caja is de MATE-bestandsbeheerder. Blader door uw bestanden, "
              "beheer bladwijzers en maak verbinding met netwerkshares. "
              "Het ondersteunt tabbladen, gesplitste weergave en bestandsvoorbeelden.",
        "pl": "Caja to menedżer plików MATE. Przeglądaj pliki, "
              "zarządzaj zakładkami i łącz się z udziałami sieciowymi. "
              "Obsługuje karty, widok podzielony i podgląd plików.",
        "ru": "Caja — файловый менеджер MATE. Просматривайте файлы, "
              "управляйте закладками и подключайтесь к сетевым ресурсам. "
              "Поддерживает вкладки, разделённый вид и предпросмотр файлов.",
        "ja": "Caja は MATE のファイルマネージャーです。ファイルの閲覧、"
              "ブックマークの管理、ネットワーク共有への接続ができます。"
              "タブ、分割表示、ファイルプレビューに対応しています。",
        "zh": "Caja 是 MATE 的文件管理器。浏览文件、管理书签、连接网络共享。"
              "支持标签页、分屏视图和文件预览。",
        "ko": "Caja는 MATE 파일 관리자입니다. 파일 탐색, "
              "북마크 관리, 네트워크 공유 연결이 가능합니다. "
              "탭, 분할 보기, 파일 미리보기를 지원합니다.",
    },
    # -- First Steps: Firewall --
    "Firewall": {
        "de": "Firewall",
        "fr": "Pare-feu",
        "es": "Cortafuegos",
        "it": "Firewall",
        "pt": "Firewall",
        "nl": "Firewall",
        "pl": "Zapora sieciowa",
        "ru": "Брандмауэр",
        "ja": "ファイアウォール",
        "zh": "防火墙",
        "ko": "방화벽",
    },
    "Your firewall (firewalld) is enabled by default to protect your computer. "
    "Open this tool to manage rules and allow specific services or ports.": {
        "de": "Ihre Firewall (firewalld) ist standardmäßig aktiviert, um Ihren Computer zu schützen. "
              "Öffnen Sie dieses Tool, um Regeln zu verwalten und bestimmte Dienste oder Ports zuzulassen.",
        "fr": "Votre pare-feu (firewalld) est activé par défaut pour protéger votre ordinateur. "
              "Ouvrez cet outil pour gérer les règles et autoriser des services ou ports spécifiques.",
        "es": "Su cortafuegos (firewalld) está activado por defecto para proteger su equipo. "
              "Abra esta herramienta para gestionar reglas y permitir servicios o puertos específicos.",
        "it": "Il firewall (firewalld) è abilitato per impostazione predefinita per proteggere il computer. "
              "Apri questo strumento per gestire le regole e consentire servizi o porte specifiche.",
        "pt": "A sua firewall (firewalld) está ativada por predefinição para proteger o seu computador. "
              "Abra esta ferramenta para gerir regras e permitir serviços ou portas específicas.",
        "nl": "Uw firewall (firewalld) is standaard ingeschakeld om uw computer te beschermen. "
              "Open dit hulpmiddel om regels te beheren en specifieke services of poorten toe te staan.",
        "pl": "Zapora sieciowa (firewalld) jest domyślnie włączona w celu ochrony komputera. "
              "Otwórz to narzędzie, aby zarządzać regułami i zezwalać na określone usługi lub porty.",
        "ru": "Брандмауэр (firewalld) включён по умолчанию для защиты вашего компьютера. "
              "Откройте этот инструмент для управления правилами и разрешения определённых служб или портов.",
        "ja": "ファイアウォール（firewalld）はコンピューターを保護するためにデフォルトで有効です。"
              "このツールを開いてルールを管理し、特定のサービスやポートを許可できます。",
        "zh": "防火墙（firewalld）默认启用以保护您的计算机。"
              "打开此工具管理规则，允许特定服务或端口。",
        "ko": "방화벽(firewalld)은 컴퓨터를 보호하기 위해 기본적으로 활성화되어 있습니다. "
              "이 도구를 열어 규칙을 관리하고 특정 서비스나 포트를 허용하세요.",
    },
    # -- First Steps: Updates --
    "Updates": {
        "de": "Aktualisierungen",
        "fr": "Mises à jour",
        "es": "Actualizaciones",
        "it": "Aggiornamenti",
        "pt": "Atualizações",
        "nl": "Updates",
        "pl": "Aktualizacje",
        "ru": "Обновления",
        "ja": "アップデート",
        "zh": "更新",
        "ko": "업데이트",
    },
    "Querencia updates automatically every 6 hours. A new system image is "
    "downloaded in the background and applied on reboot. You can also update "
    "manually. Updates are safe — you can always roll back with 'ujust rollback'.": {
        "de": "Querencia aktualisiert sich automatisch alle 6 Stunden. Ein neues System-Image "
              "wird im Hintergrund heruntergeladen und beim Neustart angewendet. Sie können auch "
              "manuell aktualisieren. Updates sind sicher — Sie können mit 'ujust rollback' jederzeit zurücksetzen.",
        "fr": "Querencia se met à jour automatiquement toutes les 6 heures. Une nouvelle image système "
              "est téléchargée en arrière-plan et appliquée au redémarrage. Vous pouvez aussi mettre à jour "
              "manuellement. Les mises à jour sont sûres — vous pouvez toujours revenir en arrière avec 'ujust rollback'.",
        "es": "Querencia se actualiza automáticamente cada 6 horas. Una nueva imagen del sistema se "
              "descarga en segundo plano y se aplica al reiniciar. También puede actualizar "
              "manualmente. Las actualizaciones son seguras — siempre puede revertir con 'ujust rollback'.",
        "it": "Querencia si aggiorna automaticamente ogni 6 ore. Una nuova immagine di sistema viene "
              "scaricata in background e applicata al riavvio. Puoi anche aggiornare "
              "manualmente. Gli aggiornamenti sono sicuri — puoi sempre tornare indietro con 'ujust rollback'.",
        "pt": "O Querencia atualiza-se automaticamente a cada 6 horas. Uma nova imagem do sistema é "
              "descarregada em segundo plano e aplicada ao reiniciar. Também pode atualizar "
              "manualmente. As atualizações são seguras — pode sempre reverter com 'ujust rollback'.",
        "nl": "Querencia werkt automatisch elke 6 uur bij. Een nieuw systeemimage wordt op de "
              "achtergrond gedownload en bij herstart toegepast. U kunt ook handmatig bijwerken. "
              "Updates zijn veilig — u kunt altijd terugdraaien met 'ujust rollback'.",
        "pl": "Querencia aktualizuje się automatycznie co 6 godzin. Nowy obraz systemu jest pobierany "
              "w tle i stosowany przy ponownym uruchomieniu. Możesz też zaktualizować ręcznie. "
              "Aktualizacje są bezpieczne — zawsze możesz cofnąć zmiany poleceniem 'ujust rollback'.",
        "ru": "Querencia автоматически обновляется каждые 6 часов. Новый образ системы загружается "
              "в фоне и применяется при перезагрузке. Вы также можете обновить вручную. "
              "Обновления безопасны — вы всегда можете откатиться с помощью 'ujust rollback'.",
        "ja": "Querencia は 6 時間ごとに自動的に更新されます。新しいシステムイメージは "
              "バックグラウンドでダウンロードされ、再起動時に適用されます。手動で更新することもできます。"
              "更新は安全です — 'ujust rollback' でいつでもロールバックできます。",
        "zh": "Querencia 每 6 小时自动更新一次。新的系统镜像在后台下载，重启时应用。"
              "您也可以手动更新。更新是安全的 — 您始终可以使用 'ujust rollback' 回滚。",
        "ko": "Querencia는 6시간마다 자동으로 업데이트됩니다. 새 시스템 이미지가 "
              "백그라운드에서 다운로드되고 재부팅 시 적용됩니다. 수동으로 업데이트할 수도 있습니다. "
              "업데이트는 안전합니다 — 'ujust rollback'으로 언제든 롤백할 수 있습니다.",
    },
    # ---- Installing Software page ----
    "Querencia Linux is an atomic system. Software is installed through "
    "three methods, each suited for different use cases.": {
        "de": "Querencia Linux ist ein atomares System. Software wird über "
              "drei Methoden installiert, die jeweils für unterschiedliche Anwendungsfälle geeignet sind.",
        "fr": "Querencia Linux est un système atomique. Les logiciels s'installent "
              "via trois méthodes, chacune adaptée à différents cas d'utilisation.",
        "es": "Querencia Linux es un sistema atómico. El software se instala "
              "mediante tres métodos, cada uno adecuado para diferentes casos de uso.",
        "it": "Querencia Linux è un sistema atomico. Il software si installa "
              "tramite tre metodi, ognuno adatto a diversi casi d'uso.",
        "pt": "O Querencia Linux é um sistema atómico. O software é instalado "
              "através de três métodos, cada um adequado a diferentes cenários.",
        "nl": "Querencia Linux is een atomair systeem. Software wordt geïnstalleerd "
              "via drie methoden, elk geschikt voor verschillende toepassingen.",
        "pl": "Querencia Linux to system atomowy. Oprogramowanie instaluje się "
              "trzema metodami, z których każda jest odpowiednia do innych zastosowań.",
        "ru": "Querencia Linux — атомарная система. Программы устанавливаются "
              "тремя способами, каждый из которых подходит для разных задач.",
        "ja": "Querencia Linux はアトミックシステムです。ソフトウェアは "
              "3 つの方法でインストールでき、それぞれ異なる用途に適しています。",
        "zh": "Querencia Linux 是一个原子化系统。软件通过三种方式安装，"
              "每种方式适合不同的使用场景。",
        "ko": "Querencia Linux는 원자적 시스템입니다. 소프트웨어는 "
              "세 가지 방법으로 설치되며, 각각 다른 용도에 적합합니다.",
    },
    # -- Software: Flatpak --
    "recommended": {
        "de": "empfohlen",
        "fr": "recommandé",
        "es": "recomendado",
        "it": "consigliato",
        "pt": "recomendado",
        "nl": "aanbevolen",
        "pl": "zalecany",
        "ru": "рекомендуется",
        "ja": "推奨",
        "zh": "推荐",
        "ko": "권장",
    },
    "Desktop apps like LibreOffice, VLC, and GIMP come from Flathub. "
    "Open Warehouse from the MATE menu or install from the terminal.": {
        "de": "Desktop-Apps wie LibreOffice, VLC und GIMP kommen von Flathub. "
              "Öffnen Sie Warehouse aus dem MATE-Menü oder installieren Sie per Terminal.",
        "fr": "Les applications de bureau comme LibreOffice, VLC et GIMP viennent de Flathub. "
              "Ouvrez Warehouse depuis le menu MATE ou installez depuis le terminal.",
        "es": "Las aplicaciones de escritorio como LibreOffice, VLC y GIMP vienen de Flathub. "
              "Abra Warehouse desde el menú de MATE o instale desde la terminal.",
        "it": "Le applicazioni desktop come LibreOffice, VLC e GIMP vengono da Flathub. "
              "Apri Warehouse dal menu MATE o installa dal terminale.",
        "pt": "As aplicações de desktop como LibreOffice, VLC e GIMP vêm do Flathub. "
              "Abra o Warehouse a partir do menu MATE ou instale a partir do terminal.",
        "nl": "Desktop-apps zoals LibreOffice, VLC en GIMP komen van Flathub. "
              "Open Warehouse vanuit het MATE-menu of installeer via de terminal.",
        "pl": "Aplikacje takie jak LibreOffice, VLC i GIMP pochodzą z Flathub. "
              "Otwórz Warehouse z menu MATE lub zainstaluj z terminala.",
        "ru": "Приложения как LibreOffice, VLC и GIMP устанавливаются из Flathub. "
              "Откройте Warehouse из меню MATE или установите из терминала.",
        "ja": "LibreOffice、VLC、GIMP などのデスクトップアプリは Flathub から入手できます。"
              "MATE メニューから Warehouse を開くか、ターミナルからインストールできます。",
        "zh": "LibreOffice、VLC、GIMP 等桌面应用来自 Flathub。"
              "从 MATE 菜单打开 Warehouse 或从终端安装。",
        "ko": "LibreOffice, VLC, GIMP 같은 데스크톱 앱은 Flathub에서 제공됩니다. "
              "MATE 메뉴에서 Warehouse를 열거나 터미널에서 설치하세요.",
    },
    # -- Software: Micromamba --
    "CLI tools": {
        "de": "CLI-Werkzeuge",
        "fr": "Outils CLI",
        "es": "Herramientas CLI",
        "it": "Strumenti CLI",
        "pt": "Ferramentas CLI",
        "nl": "CLI-tools",
        "pl": "Narzędzia CLI",
        "ru": "Консольные утилиты",
        "ja": "CLI ツール",
        "zh": "CLI 工具",
        "ko": "CLI 도구",
    },
    "CLI tools and developer packages. Works like conda but faster. "
    "Pre-installed — just open MATE Terminal and run commands.": {
        "de": "Kommandozeilen-Werkzeuge und Entwicklerpakete. Funktioniert wie conda, aber schneller. "
              "Vorinstalliert — öffnen Sie einfach das MATE-Terminal und führen Sie Befehle aus.",
        "fr": "Outils en ligne de commande et paquets de développement. Fonctionne comme conda mais plus vite. "
              "Préinstallé — ouvrez simplement le terminal MATE et exécutez des commandes.",
        "es": "Herramientas de línea de comandos y paquetes de desarrollo. Funciona como conda pero más rápido. "
              "Preinstalado — simplemente abra la terminal de MATE y ejecute comandos.",
        "it": "Strumenti a riga di comando e pacchetti per sviluppatori. Funziona come conda ma più veloce. "
              "Preinstallato — apri il terminale MATE ed esegui i comandi.",
        "pt": "Ferramentas de linha de comando e pacotes de desenvolvimento. Funciona como o conda mas mais rápido. "
              "Pré-instalado — abra o terminal MATE e execute comandos.",
        "nl": "CLI-tools en ontwikkelpakketten. Werkt als conda maar sneller. "
              "Voorgeïnstalleerd — open gewoon de MATE-terminal en voer opdrachten uit.",
        "pl": "Narzędzia wiersza poleceń i pakiety deweloperskie. Działa jak conda, ale szybciej. "
              "Preinstalowany — po prostu otwórz terminal MATE i uruchamiaj polecenia.",
        "ru": "Консольные утилиты и пакеты для разработчиков. Работает как conda, но быстрее. "
              "Предустановлен — просто откройте терминал MATE и выполняйте команды.",
        "ja": "CLI ツールと開発パッケージ。conda のように動作しますがより高速です。"
              "プリインストール済み — MATE ターミナルを開いてコマンドを実行するだけです。",
        "zh": "CLI 工具和开发者包。类似 conda 但更快。"
              "已预装 — 只需打开 MATE 终端并运行命令。",
        "ko": "CLI 도구와 개발자 패키지. conda처럼 작동하지만 더 빠릅니다. "
              "사전 설치됨 — MATE 터미널을 열고 명령을 실행하기만 하면 됩니다.",
    },
    # -- Software: Distrobox --
    "containers": {
        "de": "Container",
        "fr": "conteneurs",
        "es": "contenedores",
        "it": "contenitori",
        "pt": "contentores",
        "nl": "containers",
        "pl": "kontenery",
        "ru": "контейнеры",
        "ja": "コンテナ",
        "zh": "容器",
        "ko": "컨테이너",
    },
    "Need a full mutable Linux environment? Distrobox gives you a "
    "disposable container with dnf or apt. Perfect for development. "
    "Integrates seamlessly with the MATE Desktop.": {
        "de": "Benötigen Sie eine vollständige veränderbare Linux-Umgebung? Distrobox gibt Ihnen einen "
              "Wegwerf-Container mit dnf oder apt. Perfekt für die Entwicklung. "
              "Integriert sich nahtlos in den MATE-Desktop.",
        "fr": "Besoin d'un environnement Linux complet et modifiable ? Distrobox vous donne un "
              "conteneur jetable avec dnf ou apt. Parfait pour le développement. "
              "S'intègre parfaitement au bureau MATE.",
        "es": "¿Necesita un entorno Linux completo y modificable? Distrobox le da un "
              "contenedor desechable con dnf o apt. Perfecto para desarrollo. "
              "Se integra perfectamente con el escritorio MATE.",
        "it": "Hai bisogno di un ambiente Linux completo e modificabile? Distrobox ti dà un "
              "contenitore usa e getta con dnf o apt. Perfetto per lo sviluppo. "
              "Si integra perfettamente con il desktop MATE.",
        "pt": "Precisa de um ambiente Linux completo e modificável? O Distrobox dá-lhe um "
              "contentor descartável com dnf ou apt. Perfeito para desenvolvimento. "
              "Integra-se perfeitamente com o ambiente MATE.",
        "nl": "Heeft u een volledige aanpasbare Linux-omgeving nodig? Distrobox geeft u een "
              "wegwerpcontainer met dnf of apt. Perfect voor ontwikkeling. "
              "Integreert naadloos met het MATE-bureaublad.",
        "pl": "Potrzebujesz pełnego, modyfikowalnego środowiska Linux? Distrobox daje ci "
              "jednorazowy kontener z dnf lub apt. Idealny do programowania. "
              "Bezproblemowo integruje się z pulpitem MATE.",
        "ru": "Нужна полноценная изменяемая среда Linux? Distrobox даёт вам "
              "одноразовый контейнер с dnf или apt. Идеально для разработки. "
              "Бесшовно интегрируется с рабочим столом MATE.",
        "ja": "完全な変更可能な Linux 環境が必要ですか？Distrobox は "
              "dnf や apt を使える使い捨てコンテナを提供します。開発に最適です。"
              "MATE デスクトップとシームレスに統合されます。",
        "zh": "需要完整的可变 Linux 环境？Distrobox 提供带有 dnf 或 apt 的一次性容器。"
              "非常适合开发。与 MATE 桌面无缝集成。",
        "ko": "완전한 변경 가능한 Linux 환경이 필요하신가요? Distrobox는 "
              "dnf 또는 apt가 포함된 일회용 컨테이너를 제공합니다. 개발에 완벽합니다. "
              "MATE 데스크톱과 원활하게 통합됩니다.",
    },
    "This is an atomic system — 'dnf install' on the host is not available. "
    "This is by design for reliability and security.": {
        "de": "Dies ist ein atomares System — 'dnf install' auf dem Host ist nicht verfügbar. "
              "Das ist beabsichtigt für Zuverlässigkeit und Sicherheit.",
        "fr": "C'est un système atomique — 'dnf install' sur l'hôte n'est pas disponible. "
              "C'est intentionnel pour la fiabilité et la sécurité.",
        "es": "Este es un sistema atómico — 'dnf install' en el host no está disponible. "
              "Esto es intencionado para fiabilidad y seguridad.",
        "it": "Questo è un sistema atomico — 'dnf install' sull'host non è disponibile. "
              "Questo è intenzionale per affidabilità e sicurezza.",
        "pt": "Este é um sistema atómico — 'dnf install' no host não está disponível. "
              "Isto é intencional para fiabilidade e segurança.",
        "nl": "Dit is een atomair systeem — 'dnf install' op de host is niet beschikbaar. "
              "Dit is ontworpen voor betrouwbaarheid en veiligheid.",
        "pl": "To system atomowy — 'dnf install' na hoście nie jest dostępne. "
              "Jest to celowe dla niezawodności i bezpieczeństwa.",
        "ru": "Это атомарная система — 'dnf install' на хосте недоступен. "
              "Это сделано намеренно для надёжности и безопасности.",
        "ja": "これはアトミックシステムです — ホスト上で 'dnf install' は使用できません。"
              "信頼性とセキュリティのために、これは意図的な設計です。",
        "zh": "这是一个原子化系统 — 主机上不能使用 'dnf install'。"
              "这是为了可靠性和安全性而设计的。",
        "ko": "이것은 원자적 시스템입니다 — 호스트에서 'dnf install'은 사용할 수 없습니다. "
              "이는 안정성과 보안을 위한 의도적인 설계입니다.",
    },
    # ---- System Info page ----
    "System Information": {
        "de": "Systeminformationen",
        "fr": "Informations système",
        "es": "Información del sistema",
        "it": "Informazioni di sistema",
        "pt": "Informações do sistema",
        "nl": "Systeeminformatie",
        "pl": "Informacje o systemie",
        "ru": "Информация о системе",
        "ja": "システム情報",
        "zh": "系统信息",
        "ko": "시스템 정보",
    },
    "Copy System Info": {
        "de": "Systeminformationen kopieren",
        "fr": "Copier les informations système",
        "es": "Copiar información del sistema",
        "it": "Copia informazioni di sistema",
        "pt": "Copiar informações do sistema",
        "nl": "Systeeminformatie kopiëren",
        "pl": "Kopiuj informacje o systemie",
        "ru": "Копировать информацию о системе",
        "ja": "システム情報をコピー",
        "zh": "复制系统信息",
        "ko": "시스템 정보 복사",
    },
    "Open MATE Terminal": {
        "de": "MATE-Terminal öffnen",
        "fr": "Ouvrir le terminal MATE",
        "es": "Abrir terminal de MATE",
        "it": "Apri terminale MATE",
        "pt": "Abrir terminal MATE",
        "nl": "MATE-terminal openen",
        "pl": "Otwórz terminal MATE",
        "ru": "Открыть терминал MATE",
        "ja": "MATE ターミナルを開く",
        "zh": "打开 MATE 终端",
        "ko": "MATE 터미널 열기",
    },
    "Quick Commands": {
        "de": "Schnellbefehle",
        "fr": "Commandes rapides",
        "es": "Comandos rápidos",
        "it": "Comandi rapidi",
        "pt": "Comandos rápidos",
        "nl": "Snelcommando's",
        "pl": "Szybkie polecenia",
        "ru": "Быстрые команды",
        "ja": "クイックコマンド",
        "zh": "快捷命令",
        "ko": "빠른 명령",
    },
    "Click any command to run it in MATE Terminal.": {
        "de": "Klicken Sie auf einen Befehl, um ihn im MATE-Terminal auszuführen.",
        "fr": "Cliquez sur une commande pour l'exécuter dans le terminal MATE.",
        "es": "Haga clic en un comando para ejecutarlo en la terminal de MATE.",
        "it": "Fai clic su un comando per eseguirlo nel terminale MATE.",
        "pt": "Clique num comando para o executar no terminal MATE.",
        "nl": "Klik op een commando om het in de MATE-terminal uit te voeren.",
        "pl": "Kliknij polecenie, aby uruchomić je w terminalu MATE.",
        "ru": "Нажмите на команду, чтобы выполнить её в терминале MATE.",
        "ja": "コマンドをクリックすると MATE ターミナルで実行されます。",
        "zh": "点击任意命令在 MATE 终端中运行。",
        "ko": "명령을 클릭하면 MATE 터미널에서 실행됩니다.",
    },
    "Show image status": {
        "de": "Image-Status anzeigen",
        "fr": "Afficher l'état de l'image",
        "es": "Mostrar estado de la imagen",
        "it": "Mostra stato dell'immagine",
        "pt": "Mostrar estado da imagem",
        "nl": "Imagestatus weergeven",
        "pl": "Pokaż status obrazu",
        "ru": "Показать состояние образа",
        "ja": "イメージの状態を表示",
        "zh": "显示镜像状态",
        "ko": "이미지 상태 표시",
    },
    "Update system": {
        "de": "System aktualisieren",
        "fr": "Mettre à jour le système",
        "es": "Actualizar sistema",
        "it": "Aggiorna sistema",
        "pt": "Atualizar sistema",
        "nl": "Systeem bijwerken",
        "pl": "Aktualizuj system",
        "ru": "Обновить систему",
        "ja": "システムを更新",
        "zh": "更新系统",
        "ko": "시스템 업데이트",
    },
    "Roll back to previous image": {
        "de": "Auf vorheriges Image zurücksetzen",
        "fr": "Revenir à l'image précédente",
        "es": "Revertir a la imagen anterior",
        "it": "Torna all'immagine precedente",
        "pt": "Reverter para a imagem anterior",
        "nl": "Terugdraaien naar vorig image",
        "pl": "Przywróć poprzedni obraz",
        "ru": "Откатить к предыдущему образу",
        "ja": "前のイメージにロールバック",
        "zh": "回滚到上一个镜像",
        "ko": "이전 이미지로 롤백",
    },
    "System info (fastfetch)": {
        "de": "Systeminfo (fastfetch)",
        "fr": "Infos système (fastfetch)",
        "es": "Info del sistema (fastfetch)",
        "it": "Info di sistema (fastfetch)",
        "pt": "Info do sistema (fastfetch)",
        "nl": "Systeeminfo (fastfetch)",
        "pl": "Informacje o systemie (fastfetch)",
        "ru": "Информация о системе (fastfetch)",
        "ja": "システム情報（fastfetch）",
        "zh": "系统信息（fastfetch）",
        "ko": "시스템 정보 (fastfetch)",
    },
    # -- Info grid keys --
    "OS:": {
        "de": "Betriebssystem:",
        "fr": "Système :",
        "es": "Sistema:",
        "it": "Sistema:",
        "pt": "Sistema:",
        "nl": "Besturingssysteem:",
        "pl": "System:",
        "ru": "ОС:",
        "ja": "OS:",
        "zh": "操作系统:",
        "ko": "운영체제:",
    },
    "GPU Variant:": {
        "de": "GPU-Variante:",
        "fr": "Variante GPU :",
        "es": "Variante GPU:",
        "it": "Variante GPU:",
        "pt": "Variante GPU:",
        "nl": "GPU-variant:",
        "pl": "Wariant GPU:",
        "ru": "Вариант GPU:",
        "ja": "GPU バリアント:",
        "zh": "GPU 变体:",
        "ko": "GPU 변형:",
    },
    "Desktop:": {
        "de": "Oberfläche:",
        "fr": "Bureau :",
        "es": "Escritorio:",
        "it": "Desktop:",
        "pt": "Ambiente:",
        "nl": "Bureaublad:",
        "pl": "Pulpit:",
        "ru": "Рабочий стол:",
        "ja": "デスクトップ:",
        "zh": "桌面:",
        "ko": "데스크톱:",
    },
    "Base:": {
        "de": "Basis:",
        "fr": "Base :",
        "es": "Base:",
        "it": "Base:",
        "pt": "Base:",
        "nl": "Basis:",
        "pl": "Baza:",
        "ru": "Основа:",
        "ja": "ベース:",
        "zh": "基础:",
        "ko": "기반:",
    },
    "Image:": {
        "de": "Image:",
        "fr": "Image :",
        "es": "Imagen:",
        "it": "Immagine:",
        "pt": "Imagem:",
        "nl": "Image:",
        "pl": "Obraz:",
        "ru": "Образ:",
        "ja": "イメージ:",
        "zh": "镜像:",
        "ko": "이미지:",
    },
    "Build Date:": {
        "de": "Build-Datum:",
        "fr": "Date de build :",
        "es": "Fecha de compilación:",
        "it": "Data di build:",
        "pt": "Data de compilação:",
        "nl": "Builddatum:",
        "pl": "Data budowy:",
        "ru": "Дата сборки:",
        "ja": "ビルド日時:",
        "zh": "构建日期:",
        "ko": "빌드 날짜:",
    },
    "Kernel:": {
        "de": "Kernel:",
        "fr": "Noyau :",
        "es": "Kernel:",
        "it": "Kernel:",
        "pt": "Kernel:",
        "nl": "Kernel:",
        "pl": "Jądro:",
        "ru": "Ядро:",
        "ja": "カーネル:",
        "zh": "内核:",
        "ko": "커널:",
    },
    "Architecture:": {
        "de": "Architektur:",
        "fr": "Architecture :",
        "es": "Arquitectura:",
        "it": "Architettura:",
        "pt": "Arquitetura:",
        "nl": "Architectuur:",
        "pl": "Architektura:",
        "ru": "Архитектура:",
        "ja": "アーキテクチャ:",
        "zh": "架构:",
        "ko": "아키텍처:",
    },
    # ---- Help page ----
    "Querencia Linux is open source. Contributions, bug reports, "
    "and feedback are welcome!": {
        "de": "Querencia Linux ist Open Source. Beiträge, Fehlerberichte "
              "und Feedback sind willkommen!",
        "fr": "Querencia Linux est open source. Les contributions, signalements de bugs "
              "et retours sont les bienvenus !",
        "es": "Querencia Linux es código abierto. ¡Contribuciones, reportes de errores "
              "y comentarios son bienvenidos!",
        "it": "Querencia Linux è open source. Contributi, segnalazioni di bug "
              "e feedback sono benvenuti!",
        "pt": "O Querencia Linux é código aberto. Contribuições, relatórios de bugs "
              "e feedback são bem-vindos!",
        "nl": "Querencia Linux is open source. Bijdragen, bugrapporten "
              "en feedback zijn welkom!",
        "pl": "Querencia Linux jest oprogramowaniem open source. Kontrybucje, zgłoszenia błędów "
              "i opinie są mile widziane!",
        "ru": "Querencia Linux — проект с открытым исходным кодом. Вклад, сообщения об ошибках "
              "и отзывы приветствуются!",
        "ja": "Querencia Linux はオープンソースです。コントリビューション、バグ報告、"
              "フィードバックを歓迎します！",
        "zh": "Querencia Linux 是开源的。欢迎贡献代码、报告 Bug 和提供反馈！",
        "ko": "Querencia Linux는 오픈 소스입니다. 기여, 버그 보고, "
              "피드백을 환영합니다!",
    },
    "Website": {
        "de": "Webseite",
        "fr": "Site web",
        "es": "Sitio web",
        "it": "Sito web",
        "pt": "Website",
        "nl": "Website",
        "pl": "Strona internetowa",
        "ru": "Веб-сайт",
        "ja": "ウェブサイト",
        "zh": "网站",
        "ko": "웹사이트",
    },
    "Project homepage and documentation": {
        "de": "Projekt-Homepage und Dokumentation",
        "fr": "Page d'accueil du projet et documentation",
        "es": "Página del proyecto y documentación",
        "it": "Pagina del progetto e documentazione",
        "pt": "Página do projeto e documentação",
        "nl": "Projecthomepage en documentatie",
        "pl": "Strona główna projektu i dokumentacja",
        "ru": "Домашняя страница проекта и документация",
        "ja": "プロジェクトのホームページとドキュメント",
        "zh": "项目主页和文档",
        "ko": "프로젝트 홈페이지 및 문서",
    },
    "Source Code": {
        "de": "Quellcode",
        "fr": "Code source",
        "es": "Código fuente",
        "it": "Codice sorgente",
        "pt": "Código-fonte",
        "nl": "Broncode",
        "pl": "Kod źródłowy",
        "ru": "Исходный код",
        "ja": "ソースコード",
        "zh": "源代码",
        "ko": "소스 코드",
    },
    "Build scripts, configuration, and image definitions on GitHub": {
        "de": "Build-Skripte, Konfiguration und Image-Definitionen auf GitHub",
        "fr": "Scripts de build, configuration et définitions d'images sur GitHub",
        "es": "Scripts de compilación, configuración y definiciones de imagen en GitHub",
        "it": "Script di build, configurazione e definizioni di immagine su GitHub",
        "pt": "Scripts de compilação, configuração e definições de imagem no GitHub",
        "nl": "Build-scripts, configuratie en image-definities op GitHub",
        "pl": "Skrypty budowania, konfiguracja i definicje obrazów na GitHub",
        "ru": "Скрипты сборки, конфигурация и определения образов на GitHub",
        "ja": "GitHub 上のビルドスクリプト、設定、イメージ定義",
        "zh": "GitHub 上的构建脚本、配置和镜像定义",
        "ko": "GitHub의 빌드 스크립트, 구성, 이미지 정의",
    },
    "The enterprise Linux distribution Querencia is built on": {
        "de": "Die Enterprise-Linux-Distribution, auf der Querencia aufbaut",
        "fr": "La distribution Linux entreprise sur laquelle Querencia est basé",
        "es": "La distribución Linux empresarial en la que Querencia está basado",
        "it": "La distribuzione Linux enterprise su cui è basato Querencia",
        "pt": "A distribuição Linux empresarial em que o Querencia é baseado",
        "nl": "De enterprise Linux-distributie waarop Querencia is gebouwd",
        "pl": "Dystrybucja Linux dla przedsiębiorstw, na której oparty jest Querencia",
        "ru": "Корпоративный дистрибутив Linux, на котором основан Querencia",
        "ja": "Querencia のベースとなるエンタープライズ Linux ディストリビューション",
        "zh": "Querencia 所基于的企业级 Linux 发行版",
        "ko": "Querencia가 기반으로 하는 엔터프라이즈 Linux 배포판",
    },
    "Report a Bug": {
        "de": "Fehler melden",
        "fr": "Signaler un bug",
        "es": "Reportar un error",
        "it": "Segnala un bug",
        "pt": "Reportar um bug",
        "nl": "Bug melden",
        "pl": "Zgłoś błąd",
        "ru": "Сообщить об ошибке",
        "ja": "バグを報告",
        "zh": "报告 Bug",
        "ko": "버그 보고",
    },
    "Found an issue? Let us know on GitHub": {
        "de": "Ein Problem gefunden? Lassen Sie es uns auf GitHub wissen",
        "fr": "Vous avez trouvé un problème ? Signalez-le sur GitHub",
        "es": "¿Encontró un problema? Háganoslo saber en GitHub",
        "it": "Hai trovato un problema? Faccelo sapere su GitHub",
        "pt": "Encontrou um problema? Informe-nos no GitHub",
        "nl": "Een probleem gevonden? Laat het ons weten op GitHub",
        "pl": "Znalazłeś problem? Daj nam znać na GitHub",
        "ru": "Нашли проблему? Сообщите нам на GitHub",
        "ja": "問題を見つけましたか？GitHub で教えてください",
        "zh": "发现问题？请在 GitHub 上告诉我们",
        "ko": "문제를 발견하셨나요? GitHub에서 알려주세요",
    },
    "About Querencia Linux": {
        "de": "Über Querencia Linux",
        "fr": "À propos de Querencia Linux",
        "es": "Acerca de Querencia Linux",
        "it": "Informazioni su Querencia Linux",
        "pt": "Sobre o Querencia Linux",
        "nl": "Over Querencia Linux",
        "pl": "O Querencia Linux",
        "ru": "О Querencia Linux",
        "ja": "Querencia Linux について",
        "zh": "关于 Querencia Linux",
        "ko": "Querencia Linux에 대하여",
    },
    "Querencia (Spanish: keh-REN-see-ah) means a place where one feels "
    "safe, a place from which one draws strength — a place where you feel "
    "at home.\n\n"
    "Built on the rock-solid foundation of AlmaLinux, with the familiar "
    "MATE Desktop, and the safety of atomic updates.": {
        "de": "Querencia (Spanisch: keh-REN-see-ah) bedeutet ein Ort, an dem man sich "
              "sicher fühlt, ein Ort, aus dem man Kraft schöpft — ein Ort, an dem man sich "
              "zu Hause fühlt.\n\n"
              "Gebaut auf dem soliden Fundament von AlmaLinux, mit dem vertrauten "
              "MATE-Desktop und der Sicherheit atomarer Aktualisierungen.",
        "fr": "Querencia (espagnol : keh-REN-see-ah) signifie un lieu où l'on se sent "
              "en sécurité, un lieu d'où l'on tire sa force — un lieu où l'on se sent "
              "chez soi.\n\n"
              "Construit sur les fondations solides d'AlmaLinux, avec le bureau MATE "
              "familier et la sécurité des mises à jour atomiques.",
        "es": "Querencia (en español: keh-REN-see-ah) significa un lugar donde uno se siente "
              "seguro, un lugar del que se extrae fortaleza — un lugar donde uno se siente "
              "en casa.\n\n"
              "Construido sobre la sólida base de AlmaLinux, con el familiar "
              "escritorio MATE y la seguridad de las actualizaciones atómicas.",
        "it": "Querencia (spagnolo: keh-REN-see-ah) significa un luogo dove ci si sente "
              "al sicuro, un luogo da cui si trae forza — un luogo dove ci si sente "
              "a casa.\n\n"
              "Costruito sulle solide fondamenta di AlmaLinux, con il familiare "
              "desktop MATE e la sicurezza degli aggiornamenti atomici.",
        "pt": "Querencia (espanhol: keh-REN-see-ah) significa um lugar onde nos sentimos "
              "seguros, um lugar de onde tiramos força — um lugar onde nos sentimos "
              "em casa.\n\n"
              "Construído sobre a base sólida do AlmaLinux, com o familiar "
              "ambiente MATE e a segurança das atualizações atómicas.",
        "nl": "Querencia (Spaans: keh-REN-see-ah) betekent een plek waar men zich "
              "veilig voelt, een plek waaruit men kracht put — een plek waar men zich "
              "thuis voelt.\n\n"
              "Gebouwd op het rotsvaste fundament van AlmaLinux, met het vertrouwde "
              "MATE-bureaublad en de veiligheid van atomaire updates.",
        "pl": "Querencia (hiszpański: keh-REN-see-ah) oznacza miejsce, w którym czujemy się "
              "bezpiecznie, miejsce, z którego czerpiemy siłę — miejsce, w którym czujemy się "
              "jak w domu.\n\n"
              "Zbudowany na solidnym fundamencie AlmaLinux, ze znajomym "
              "pulpitem MATE i bezpieczeństwem atomowych aktualizacji.",
        "ru": "Querencia (исп.: кех-РЕН-сия) означает место, где чувствуешь себя "
              "в безопасности, место, откуда черпаешь силу — место, где чувствуешь себя "
              "как дома.\n\n"
              "Построен на надёжном фундаменте AlmaLinux, со знакомым "
              "рабочим столом MATE и безопасностью атомарных обновлений.",
        "ja": "Querencia（スペイン語：ケレンシア）は、安心できる場所、"
              "力を引き出せる場所、つまり家のように感じる場所を意味します。\n\n"
              "AlmaLinux の堅固な基盤の上に、親しみのある MATE デスクトップと"
              "アトミックアップデートの安全性を備えて構築されています。",
        "zh": "Querencia（西班牙语：keh-REN-see-ah）意为一个让人感到安全的地方，"
              "一个汲取力量的地方 — 一个感觉像家的地方。\n\n"
              "构建在 AlmaLinux 的坚实基础之上，拥有熟悉的 MATE 桌面和原子化更新的安全保障。",
        "ko": "Querencia(스페인어: keh-REN-see-ah)는 안전하게 느끼는 곳, "
              "힘을 끌어내는 곳 — 집처럼 느끼는 곳을 의미합니다.\n\n"
              "AlmaLinux의 견고한 기반 위에, 익숙한 MATE 데스크톱과 "
              "원자적 업데이트의 안전성을 갖추고 있습니다.",
    },
    # ---- Bottom toolbar ----
    "Show this dialog at startup": {
        "de": "Diesen Dialog beim Start anzeigen",
        "fr": "Afficher cette fenêtre au démarrage",
        "es": "Mostrar este diálogo al inicio",
        "it": "Mostra questa finestra all'avvio",
        "pt": "Mostrar esta janela ao iniciar",
        "nl": "Dit venster bij opstarten tonen",
        "pl": "Pokaż to okno przy uruchomieniu",
        "ru": "Показывать это окно при запуске",
        "ja": "起動時にこのダイアログを表示する",
        "zh": "启动时显示此对话框",
        "ko": "시작할 때 이 대화 상자 표시",
    },
    # ---- Error dialogs ----
    "Failed to launch": {
        "de": "Start fehlgeschlagen",
        "fr": "Échec du lancement",
        "es": "Error al iniciar",
        "it": "Avvio fallito",
        "pt": "Falha ao iniciar",
        "nl": "Starten mislukt",
        "pl": "Uruchomienie nie powiodło się",
        "ru": "Не удалось запустить",
        "ja": "起動に失敗しました",
        "zh": "启动失败",
        "ko": "실행 실패",
    },
    "Warehouse not found": {
        "de": "Warehouse nicht gefunden",
        "fr": "Warehouse introuvable",
        "es": "Warehouse no encontrado",
        "it": "Warehouse non trovato",
        "pt": "Warehouse não encontrado",
        "nl": "Warehouse niet gevonden",
        "pl": "Warehouse nie znaleziony",
        "ru": "Warehouse не найден",
        "ja": "Warehouse が見つかりません",
        "zh": "未找到 Warehouse",
        "ko": "Warehouse를 찾을 수 없음",
    },
    "Warehouse doesn't appear to be installed yet. "
    "It will be set up automatically on first boot, or you can install it manually:\n\n"
    "flatpak install flathub io.github.flattool.Warehouse": {
        "de": "Warehouse scheint noch nicht installiert zu sein. "
              "Es wird beim ersten Start automatisch eingerichtet, oder Sie können es manuell installieren:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "fr": "Warehouse ne semble pas encore être installé. "
              "Il sera configuré automatiquement au premier démarrage, ou vous pouvez l'installer manuellement :\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "es": "Warehouse no parece estar instalado aún. "
              "Se configurará automáticamente en el primer inicio, o puede instalarlo manualmente:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "it": "Warehouse non sembra essere ancora installato. "
              "Verrà configurato automaticamente al primo avvio, oppure puoi installarlo manualmente:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "pt": "O Warehouse não parece estar instalado. "
              "Será configurado automaticamente na primeira inicialização, ou pode instalá-lo manualmente:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "nl": "Warehouse lijkt nog niet geïnstalleerd te zijn. "
              "Het wordt automatisch ingesteld bij de eerste start, of u kunt het handmatig installeren:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "pl": "Warehouse nie wydaje się być jeszcze zainstalowany. "
              "Zostanie automatycznie skonfigurowany przy pierwszym uruchomieniu, lub możesz go zainstalować ręcznie:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "ru": "Warehouse ещё не установлен. "
              "Он будет настроен автоматически при первом запуске, или вы можете установить его вручную:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "ja": "Warehouse はまだインストールされていないようです。"
              "初回起動時に自動的にセットアップされます。手動でインストールすることもできます：\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "zh": "Warehouse 似乎尚未安装。"
              "它将在首次启动时自动配置，或者您可以手动安装：\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
        "ko": "Warehouse가 아직 설치되지 않은 것 같습니다. "
              "첫 부팅 시 자동으로 설정되거나, 수동으로 설치할 수 있습니다:\n\n"
              "flatpak install flathub io.github.flattool.Warehouse",
    },
}


def _(text):
    """Translate a string to the current language. Falls back to English (the key)."""
    if CURRENT_LANG == "en":
        return text
    entry = TRANSLATIONS.get(text)
    if entry:
        return entry.get(CURRENT_LANG, text)
    return text


# =============================================================================
# Constants
# =============================================================================

APP_ID = "org.querencia.welcome"
WINDOW_WIDTH = 850
WINDOW_HEIGHT = 550

TERRACOTTA = "#C75230"
TERRACOTTA_DARK = "#A33D1E"
TERRACOTTA_LIGHT = "#F4BDAD"
TERRACOTTA_BG = "#FDF0EC"

CONFIG_DIR = os.path.expanduser("~/.config/querencia-welcome")
NORUN_FLAG = os.path.join(CONFIG_DIR, "norun.flag")
OS_RELEASE_PATH = "/usr/lib/os-release"
IMAGE_INFO_PATH = "/usr/share/querencia/image-info.json"

# =============================================================================
# CSS — Terracotta accent on top of the BlueMenta GTK theme
# =============================================================================

CSS = f"""
/* Terracotta accent for suggested-action buttons */
button.suggested-action {{
    background-image: none;
    background-color: {TERRACOTTA};
    color: #FFFFFF;
    border: none;
    border-radius: 5px;
    padding: 8px 20px;
    font-weight: bold;
}}
button.suggested-action:hover {{
    background-color: {TERRACOTTA_DARK};
}}
button.suggested-action:active {{
    background-color: #8C2E14;
}}

/* Welcome title */
.welcome-title {{
    color: {TERRACOTTA};
}}

/* Subtitle */
.welcome-subtitle {{
    color: #6B5B4D;
}}

/* Section heading inside pages */
.section-heading {{
    color: {TERRACOTTA};
    font-weight: bold;
}}

/* Version badge */
.version-badge {{
    background-color: {TERRACOTTA_BG};
    border: 1px solid {TERRACOTTA_LIGHT};
    border-radius: 12px;
    padding: 4px 14px;
    color: {TERRACOTTA};
    font-size: 0.9em;
}}

/* Card-style frames */
.card-frame {{
    background-color: @theme_bg_color;
    border: 1px solid alpha(@theme_fg_color, 0.12);
    border-radius: 8px;
    padding: 12px;
}}

/* Info grid labels */
.info-key {{
    font-weight: bold;
    color: #6B5B4D;
}}
.info-value {{
    color: @theme_fg_color;
}}

/* Sidebar styling — terracotta highlight for selected row */
.sidebar-listbox row:selected {{
    background-color: {TERRACOTTA};
    color: #FFFFFF;
}}
.sidebar-listbox row:selected label {{
    color: #FFFFFF;
}}
.sidebar-listbox row:selected image {{
    color: #FFFFFF;
}}
.sidebar-listbox row {{
    padding: 10px 14px;
    border-radius: 0;
}}
.sidebar-listbox {{
    background-color: @theme_bg_color;
}}

/* Note box */
.note-box {{
    background-color: {TERRACOTTA_BG};
    border: 1px solid {TERRACOTTA_LIGHT};
    border-radius: 6px;
    padding: 12px;
}}
.note-box label {{
    color: {TERRACOTTA_DARK};
}}

/* ujust command row */
.ujust-row {{
    border: 1px solid alpha(@theme_fg_color, 0.08);
    border-radius: 6px;
    padding: 6px 12px;
}}
.ujust-row:hover {{
    background-color: alpha({TERRACOTTA}, 0.06);
}}

/* Link-style buttons */
.link-row {{
    border: 1px solid alpha(@theme_fg_color, 0.08);
    border-radius: 6px;
    padding: 8px 14px;
}}
.link-row:hover {{
    background-color: alpha({TERRACOTTA}, 0.06);
}}

/* Software method cards */
.method-card {{
    background-color: @theme_bg_color;
    border: 1px solid alpha(@theme_fg_color, 0.12);
    border-radius: 8px;
    padding: 16px;
}}

/* Bottom toolbar */
.bottom-toolbar {{
    border-top: 1px solid alpha(@theme_fg_color, 0.12);
    padding: 8px 16px;
}}
"""


# =============================================================================
# System info helpers
# =============================================================================


def read_os_release():
    """Parse /usr/lib/os-release into a dict."""
    data = {}
    try:
        with open(OS_RELEASE_PATH, "r") as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    key, _, value = line.partition("=")
                    value = value.strip().strip('"').strip("'")
                    data[key] = value
    except Exception:
        pass
    return data


def read_image_info():
    """Read /usr/share/querencia/image-info.json."""
    try:
        with open(IMAGE_INFO_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def get_pretty_name():
    return read_os_release().get("PRETTY_NAME", "Querencia Linux")


def get_gpu_variant():
    return read_image_info().get("gpu-variant", "Unknown")


def get_image_ref():
    return read_image_info().get("image-ref", "Unknown")


def get_build_date():
    return read_image_info().get("build-date", "Unknown")


def get_kernel():
    try:
        return platform.release()
    except Exception:
        return "Unknown"


def get_arch():
    try:
        return platform.machine()
    except Exception:
        return "Unknown"


def collect_system_info_text():
    """Return a multi-line string with all system info for clipboard copy."""
    lines = [
        f"OS: {get_pretty_name()}",
        f"GPU Variant: {get_gpu_variant()}",
        f"Desktop: MATE",
        f"Base: AlmaLinux 10",
        f"Image: {get_image_ref()}",
        f"Build Date: {get_build_date()}",
        f"Kernel: {get_kernel()}",
        f"Architecture: {get_arch()}",
    ]
    return "\n".join(lines)


# =============================================================================
# Launcher helpers — all MATE-specific
# =============================================================================


def launch_command(cmd, shell=False):
    """Launch a command in the background. cmd is a list or string."""
    try:
        if shell:
            subprocess.Popen(cmd, shell=True)
        else:
            subprocess.Popen(cmd)
    except Exception as e:
        dialog = Gtk.MessageDialog(
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=_("Failed to launch"),
        )
        dialog.format_secondary_text(str(e))
        dialog.run()
        dialog.destroy()


def open_url(url):
    """Open a URL with xdg-open."""
    launch_command(["xdg-open", url])


def run_ujust_in_terminal(recipe):
    """Run a ujust command inside mate-terminal (MATE-specific)."""
    launch_command(
        [
            "mate-terminal",
            "-e",
            f"bash -c 'ujust {recipe}; echo; read -r -p \"Press Enter to close...\"'",
        ]
    )


# =============================================================================
# Widget factory helpers
# =============================================================================


def make_label(text, wrap=True, xalign=0.0, selectable=False, markup=False):
    label = Gtk.Label()
    if markup:
        label.set_markup(text)
    else:
        label.set_text(text)
    label.set_xalign(xalign)
    label.set_yalign(0.0)
    if wrap:
        label.set_line_wrap(True)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        label.set_max_width_chars(70)
    label.set_selectable(selectable)
    return label


def make_heading(text, scale=1.2):
    label = Gtk.Label()
    label.set_markup(f"<b>{GLib.markup_escape_text(text)}</b>")
    label.set_xalign(0.0)
    attrs = Pango.AttrList()
    attrs.insert(Pango.attr_scale_new(scale))
    label.set_attributes(attrs)
    label.get_style_context().add_class("section-heading")
    return label


def make_icon_button(label_text, icon_name, style_class=None, tooltip=None):
    btn = Gtk.Button()
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    if icon_name:
        img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
        box.pack_start(img, False, False, 0)
    lbl = Gtk.Label(label=label_text)
    box.pack_start(lbl, False, False, 0)
    btn.add(box)
    if style_class:
        btn.get_style_context().add_class(style_class)
    if tooltip:
        btn.set_tooltip_text(tooltip)
    return btn


# =============================================================================
# Page builders — All MATE-specific content
# =============================================================================


def build_welcome_page(stack):
    """Page 1: Welcome — introduces Querencia Linux + MATE Desktop."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    # Title
    title = Gtk.Label()
    title.set_markup(
        f"<b>{GLib.markup_escape_text(_('Welcome to Querencia Linux'))}</b>"
    )
    title.set_xalign(0.0)
    attrs = Pango.AttrList()
    attrs.insert(Pango.attr_scale_new(1.6))
    title.set_attributes(attrs)
    title.get_style_context().add_class("welcome-title")
    page.pack_start(title, False, False, 0)

    # Subtitle
    subtitle = Gtk.Label()
    subtitle.set_markup(
        f"<i>{GLib.markup_escape_text(_('Where Linux Feels at Home'))}</i>"
    )
    subtitle.set_xalign(0.0)
    attrs2 = Pango.AttrList()
    attrs2.insert(Pango.attr_scale_new(1.1))
    subtitle.set_attributes(attrs2)
    subtitle.get_style_context().add_class("welcome-subtitle")
    page.pack_start(subtitle, False, False, 0)

    # Separator
    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4
    )

    # Description
    desc = make_label(
        _(
            "Querencia Linux is an atomic, immutable desktop built on AlmaLinux 10 "
            "with the MATE Desktop Environment. Your system updates itself as a whole "
            "image — safe, reliable, and always rollback-ready."
        )
    )
    page.pack_start(desc, False, False, 0)

    # Version badge
    pretty = get_pretty_name()
    badge_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
    badge_label = Gtk.Label()
    badge_label.set_text(pretty)
    badge_label.get_style_context().add_class("version-badge")
    badge_box.pack_start(badge_label, False, False, 0)
    page.pack_start(badge_box, False, False, 4)

    # Spacer
    page.pack_start(Gtk.Box(), True, True, 0)

    # "Let's get started!" button
    btn = Gtk.Button(label=_("Let's get started!"))
    btn.get_style_context().add_class("suggested-action")
    btn.set_halign(Gtk.Align.START)
    btn.set_size_request(200, -1)
    btn.connect("clicked", lambda _b: stack.set_visible_child_name("first-steps"))
    page.pack_start(btn, False, False, 0)

    return page


def _make_first_step_row(icon_name, title, description, callback):
    """Build a single first-step item row with icon, text, and button."""
    frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
    frame.get_style_context().add_class("card-frame")
    frame.set_border_width(4)

    # Icon
    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.DIALOG)
    icon.set_pixel_size(40)
    icon.set_valign(Gtk.Align.CENTER)
    frame.pack_start(icon, False, False, 0)

    # Text box
    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    text_box.set_valign(Gtk.Align.CENTER)

    title_label = Gtk.Label()
    title_label.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
    title_label.set_xalign(0.0)
    text_box.pack_start(title_label, False, False, 0)

    desc_label = make_label(description)
    desc_label.set_line_wrap(True)
    desc_label.set_max_width_chars(55)
    text_box.pack_start(desc_label, False, False, 0)

    frame.pack_start(text_box, True, True, 0)

    # Open button
    btn = Gtk.Button(label=_("Open"))
    btn.set_valign(Gtk.Align.CENTER)
    btn.connect("clicked", callback)
    frame.pack_start(btn, False, False, 0)

    return frame


def build_first_steps_page():
    """Page 2: First Steps — MATE-specific tools and actions."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading(_("First Steps"), 1.3)
    page.pack_start(heading, False, False, 0)

    desc = make_label(
        _(
            'Get familiar with your MATE Desktop. Click "Open" to launch each tool.'
        )
    )
    page.pack_start(desc, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    # Scrollable area for items
    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    items_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)

    # 1. Appearance (MATE Appearance Preferences)
    items_box.pack_start(
        _make_first_step_row(
            "preferences-desktop-theme-symbolic",
            _("Appearance"),
            _(
                "Customize your MATE Desktop theme, icons, and fonts. "
                "Querencia comes with the BlueMenta theme, Noto fonts, "
                "and the Adwaita cursor."
            ),
            lambda _b: launch_command(["mate-appearance-properties"]),
        ),
        False,
        False,
        0,
    )

    # 2. App Store (Warehouse — Flatpak frontend)
    def _open_warehouse(_btn):
        try:
            subprocess.Popen(["flatpak", "run", "io.github.flattool.Warehouse"])
        except Exception:
            dialog = Gtk.MessageDialog(
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text=_("Warehouse not found"),
            )
            dialog.format_secondary_text(
                _(
                    "Warehouse doesn't appear to be installed yet. "
                    "It will be set up automatically on first boot, or you can install it manually:\n\n"
                    "flatpak install flathub io.github.flattool.Warehouse"
                )
            )
            dialog.run()
            dialog.destroy()

    items_box.pack_start(
        _make_first_step_row(
            "system-software-install-symbolic",
            _("App Store (Warehouse)"),
            _(
                "Browse and install apps from Flathub using Warehouse. "
                "On an atomic system like Querencia, all desktop apps are Flatpaks — "
                "sandboxed and independent of the base system."
            ),
            _open_warehouse,
        ),
        False,
        False,
        0,
    )

    # 3. MATE Control Center
    items_box.pack_start(
        _make_first_step_row(
            "preferences-system-symbolic",
            _("MATE Control Center"),
            _(
                "Configure displays, keyboard layouts, mouse, network, "
                "default applications, and more. This is the central settings "
                "hub for the MATE Desktop."
            ),
            lambda _b: launch_command(["mate-control-center"]),
        ),
        False,
        False,
        0,
    )

    # 4. File Manager (Caja — the MATE file manager)
    items_box.pack_start(
        _make_first_step_row(
            "system-file-manager-symbolic",
            _("File Manager (Caja)"),
            _(
                "Caja is the MATE file manager. Browse your files, "
                "manage bookmarks, and connect to network shares. "
                "It supports tabs, split view, and file previews."
            ),
            lambda _b: launch_command(["caja"]),
        ),
        False,
        False,
        0,
    )

    # 5. Firewall
    items_box.pack_start(
        _make_first_step_row(
            "security-high-symbolic",
            _("Firewall"),
            _(
                "Your firewall (firewalld) is enabled by default to protect your computer. "
                "Open this tool to manage rules and allow specific services or ports."
            ),
            lambda _b: launch_command(["firewall-config"]),
        ),
        False,
        False,
        0,
    )

    # 6. Updates (via ujust in mate-terminal)
    items_box.pack_start(
        _make_first_step_row(
            "software-update-available-symbolic",
            _("Updates"),
            _(
                "Querencia updates automatically every 6 hours. A new system image is "
                "downloaded in the background and applied on reboot. You can also update "
                "manually. Updates are safe — you can always roll back with 'ujust rollback'."
            ),
            lambda _b: run_ujust_in_terminal("update"),
        ),
        False,
        False,
        0,
    )

    scroll.add(items_box)
    page.pack_start(scroll, True, True, 0)

    return page


def _make_method_card(icon_name, title, tag, description, example_cmd=None):
    """Build a software installation method card."""
    frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    frame.get_style_context().add_class("method-card")

    # Header row
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
    header.pack_start(icon, False, False, 0)

    title_label = Gtk.Label()
    title_label.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
    title_label.set_xalign(0.0)
    header.pack_start(title_label, True, True, 0)

    if tag:
        tag_label = Gtk.Label()
        tag_label.set_markup(f"<small><i>{GLib.markup_escape_text(tag)}</i></small>")
        tag_label.get_style_context().add_class("version-badge")
        header.pack_start(tag_label, False, False, 0)

    frame.pack_start(header, False, False, 0)

    # Description
    desc = make_label(description)
    frame.pack_start(desc, False, False, 0)

    # Example command (monospace, selectable — for copy-pasting in mate-terminal)
    if example_cmd:
        cmd_label = Gtk.Label()
        cmd_label.set_markup(
            f"<tt><small>{GLib.markup_escape_text(example_cmd)}</small></tt>"
        )
        cmd_label.set_xalign(0.0)
        cmd_label.set_selectable(True)
        frame.pack_start(cmd_label, False, False, 0)

    return frame


def build_software_page():
    """Page 3: Installing Software — explains Flatpak / Micromamba / Distrobox."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading(_("Installing Software"), 1.3)
    page.pack_start(heading, False, False, 0)

    desc = make_label(
        _(
            "Querencia Linux is an atomic system. Software is installed through "
            "three methods, each suited for different use cases."
        )
    )
    page.pack_start(desc, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    cards_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)

    # Flatpak
    cards_box.pack_start(
        _make_method_card(
            "system-software-install-symbolic",
            "Flatpak",
            _("recommended"),
            _(
                "Desktop apps like LibreOffice, VLC, and GIMP come from Flathub. "
                "Open Warehouse from the MATE menu or install from the terminal."
            ),
            "flatpak install flathub org.example.App",
        ),
        False,
        False,
        0,
    )

    # Micromamba
    cards_box.pack_start(
        _make_method_card(
            "utilities-terminal-symbolic",
            "Micromamba",
            _("CLI tools"),
            _(
                "CLI tools and developer packages. Works like conda but faster. "
                "Pre-installed — just open MATE Terminal and run commands."
            ),
            "micromamba install ripgrep bat fd-find",
        ),
        False,
        False,
        0,
    )

    # Distrobox
    cards_box.pack_start(
        _make_method_card(
            "computer-symbolic",
            "Distrobox",
            _("containers"),
            _(
                "Need a full mutable Linux environment? Distrobox gives you a "
                "disposable container with dnf or apt. Perfect for development. "
                "Integrates seamlessly with the MATE Desktop."
            ),
            "distrobox create --name dev --image fedora:latest",
        ),
        False,
        False,
        0,
    )

    scroll.add(cards_box)
    page.pack_start(scroll, True, True, 0)

    # Note box
    note_frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    note_frame.get_style_context().add_class("note-box")
    note_icon = Gtk.Image.new_from_icon_name(
        "dialog-information-symbolic", Gtk.IconSize.MENU
    )
    note_frame.pack_start(note_icon, False, False, 0)
    note_label = make_label(
        _(
            "This is an atomic system — 'dnf install' on the host is not available. "
            "This is by design for reliability and security."
        )
    )
    note_frame.pack_start(note_label, True, True, 0)
    page.pack_start(note_frame, False, False, 4)

    return page


def build_sysinfo_page():
    """Page 4: System Info — reads from os-release + image-info.json."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading(_("System Information"), 1.3)
    page.pack_start(heading, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)

    # Info grid
    grid = Gtk.Grid()
    grid.set_column_spacing(16)
    grid.set_row_spacing(8)

    info_items = [
        (_("OS:"), get_pretty_name()),
        (_("GPU Variant:"), get_gpu_variant()),
        (_("Desktop:"), "MATE"),
        (_("Base:"), "AlmaLinux 10"),
        (_("Image:"), get_image_ref()),
        (_("Build Date:"), get_build_date()),
        (_("Kernel:"), get_kernel()),
        (_("Architecture:"), get_arch()),
    ]

    for row_idx, (key, value) in enumerate(info_items):
        key_label = Gtk.Label(label=key)
        key_label.set_xalign(1.0)
        key_label.get_style_context().add_class("info-key")
        grid.attach(key_label, 0, row_idx, 1, 1)

        val_label = Gtk.Label(label=value)
        val_label.set_xalign(0.0)
        val_label.set_selectable(True)
        val_label.set_line_wrap(True)
        val_label.set_max_width_chars(50)
        val_label.get_style_context().add_class("info-value")
        grid.attach(val_label, 1, row_idx, 1, 1)

    content_box.pack_start(grid, False, False, 0)

    # Buttons row
    btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

    copy_btn = make_icon_button(
        _("Copy System Info"), "edit-copy-symbolic"
    )
    copy_btn.connect("clicked", _on_copy_sysinfo)
    btn_box.pack_start(copy_btn, False, False, 0)

    term_btn = make_icon_button(
        _("Open MATE Terminal"), "utilities-terminal-symbolic"
    )
    term_btn.connect(
        "clicked", lambda _b: launch_command(["mate-terminal"])
    )
    btn_box.pack_start(term_btn, False, False, 0)

    content_box.pack_start(btn_box, False, False, 0)

    # ujust quick commands
    content_box.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4
    )

    ujust_heading = make_heading(_("Quick Commands") + " (ujust)", 1.1)
    content_box.pack_start(ujust_heading, False, False, 0)

    ujust_desc = make_label(_("Click any command to run it in MATE Terminal."))
    content_box.pack_start(ujust_desc, False, False, 0)

    ujust_commands = [
        ("ujust status", _("Show image status"), "status"),
        ("ujust update", _("Update system"), "update"),
        ("ujust rollback", _("Roll back to previous image"), "rollback"),
        ("ujust info", _("System info (fastfetch)"), "info"),
    ]

    for cmd_text, cmd_desc, recipe in ujust_commands:
        row = Gtk.Button()
        row.set_relief(Gtk.ReliefStyle.NONE)
        row.get_style_context().add_class("ujust-row")

        row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        cmd_label = Gtk.Label()
        cmd_label.set_markup(f"<tt><b>{GLib.markup_escape_text(cmd_text)}</b></tt>")
        cmd_label.set_xalign(0.0)
        row_box.pack_start(cmd_label, False, False, 0)

        dash_label = Gtk.Label(label="—")
        row_box.pack_start(dash_label, False, False, 0)

        desc_label = Gtk.Label(label=cmd_desc)
        desc_label.set_xalign(0.0)
        row_box.pack_start(desc_label, True, True, 0)

        run_icon = Gtk.Image.new_from_icon_name(
            "media-playback-start-symbolic", Gtk.IconSize.MENU
        )
        row_box.pack_start(run_icon, False, False, 0)

        row.add(row_box)
        row.connect("clicked", lambda _btn, r=recipe: run_ujust_in_terminal(r))
        content_box.pack_start(row, False, False, 0)

    scroll.add(content_box)
    page.pack_start(scroll, True, True, 0)

    return page


def _on_copy_sysinfo(_btn):
    """Copy system info to clipboard (uses GTK clipboard, works in MATE)."""
    text = collect_system_info_text()
    clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard.set_text(text, -1)
    clipboard.store()


def _make_link_row(icon_name, title, description, url):
    """Build a clickable link row."""
    row = Gtk.Button()
    row.set_relief(Gtk.ReliefStyle.NONE)
    row.get_style_context().add_class("link-row")

    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

    icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
    icon.set_pixel_size(24)
    box.pack_start(icon, False, False, 0)

    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    title_label = Gtk.Label()
    title_label.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
    title_label.set_xalign(0.0)
    text_box.pack_start(title_label, False, False, 0)

    desc_label = Gtk.Label()
    desc_label.set_markup(f"<small>{GLib.markup_escape_text(description)}</small>")
    desc_label.set_xalign(0.0)
    desc_label.set_line_wrap(True)
    desc_label.set_max_width_chars(50)
    text_box.pack_start(desc_label, False, False, 0)
    box.pack_start(text_box, True, True, 0)

    arrow = Gtk.Image.new_from_icon_name("go-next-symbolic", Gtk.IconSize.MENU)
    box.pack_start(arrow, False, False, 0)

    row.add(box)
    row.connect("clicked", lambda _b: open_url(url))
    return row


def build_help_page():
    """Page 5: Help & Links."""
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.set_border_width(24)
    page.set_valign(Gtk.Align.START)

    heading = make_heading(_("Help & Links"), 1.3)
    page.pack_start(heading, False, False, 0)

    desc = make_label(
        _(
            "Querencia Linux is open source. Contributions, bug reports, "
            "and feedback are welcome!"
        )
    )
    page.pack_start(desc, False, False, 0)

    page.pack_start(
        Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2
    )

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

    links_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

    links_box.pack_start(
        _make_link_row(
            "web-browser-symbolic",
            _("Website"),
            "querencialinux.org — " + _("Project homepage and documentation"),
            "https://querencialinux.org",
        ),
        False,
        False,
        0,
    )

    links_box.pack_start(
        _make_link_row(
            "text-x-script-symbolic",
            _("Source Code") + " (GitHub)",
            _("Build scripts, configuration, and image definitions on GitHub"),
            "https://github.com/endegelaende/querencia-linux",
        ),
        False,
        False,
        0,
    )

    links_box.pack_start(
        _make_link_row(
            "computer-symbolic",
            "AlmaLinux",
            _("The enterprise Linux distribution Querencia is built on"),
            "https://almalinux.org",
        ),
        False,
        False,
        0,
    )

    links_box.pack_start(
        _make_link_row(
            "dialog-warning-symbolic",
            _("Report a Bug"),
            _("Found an issue? Let us know on GitHub"),
            "https://github.com/endegelaende/querencia-linux/issues",
        ),
        False,
        False,
        0,
    )

    # About Querencia explanation
    links_box.pack_start(Gtk.Box(), False, False, 4)

    community_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    community_frame.get_style_context().add_class("card-frame")

    community_heading = Gtk.Label()
    community_heading.set_markup(
        f"<b>{GLib.markup_escape_text(_('About Querencia Linux'))}</b>"
    )
    community_heading.set_xalign(0.0)
    community_frame.pack_start(community_heading, False, False, 0)

    community_text = make_label(
        _(
            "Querencia (Spanish: keh-REN-see-ah) means a place where one feels "
            "safe, a place from which one draws strength — a place where you feel "
            "at home.\n\n"
            "Built on the rock-solid foundation of AlmaLinux, with the familiar "
            "MATE Desktop, and the safety of atomic updates."
        )
    )
    community_frame.pack_start(community_text, False, False, 0)

    links_box.pack_start(community_frame, False, False, 0)

    scroll.add(links_box)
    page.pack_start(scroll, True, True, 0)

    return page


# =============================================================================
# Sidebar
# =============================================================================

# Page definitions: (id, translated_label, icon_name)
# Labels are translated at build time via _()
PAGES = [
    ("welcome", "Welcome", "go-home-symbolic"),
    ("first-steps", "First Steps", "dialog-information-symbolic"),
    ("software", "Installing Software", "system-software-install-symbolic"),
    ("sysinfo", "System Info", "computer-symbolic"),
    ("help", "Help & Links", "help-browser-symbolic"),
]


def build_sidebar(stack):
    """Build a ListBox sidebar that switches the stack."""
    listbox = Gtk.ListBox()
    listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
    listbox.get_style_context().add_class("sidebar-listbox")

    for page_id, page_label, icon_name in PAGES:
        row = Gtk.ListBoxRow()
        row.page_id = page_id

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.set_border_width(4)

        icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
        box.pack_start(icon, False, False, 0)

        label = Gtk.Label(label=_(page_label))
        label.set_xalign(0.0)
        box.pack_start(label, True, True, 0)

        row.add(box)
        listbox.add(row)

    def on_row_selected(_lb, row):
        if row is not None:
            stack.set_visible_child_name(row.page_id)

    listbox.connect("row-selected", on_row_selected)

    return listbox


# =============================================================================
# Main Window
# =============================================================================


class WelcomeWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(
            application=app,
            title=_("Welcome to Querencia Linux"),
        )
        self.set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # HeaderBar (MATE-style: shows subtitle)
        header = Gtk.HeaderBar()
        header.set_show_close_button(True)
        header.set_title(_("Welcome to Querencia Linux"))
        header.set_subtitle(_("Where Linux Feels at Home"))
        self.set_titlebar(header)

        # Main layout: vertical box containing content + bottom toolbar
        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Content area: sidebar | separator | stack
        content_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)

        # Stack (pages)
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_UP_DOWN)
        self.stack.set_transition_duration(200)

        # Build and add pages
        self.stack.add_named(build_welcome_page(self.stack), "welcome")
        self.stack.add_named(build_first_steps_page(), "first-steps")
        self.stack.add_named(build_software_page(), "software")
        self.stack.add_named(build_sysinfo_page(), "sysinfo")
        self.stack.add_named(build_help_page(), "help")

        # Sidebar
        sidebar_scroll = Gtk.ScrolledWindow()
        sidebar_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sidebar_scroll.set_size_request(180, -1)

        self.sidebar = build_sidebar(self.stack)
        sidebar_scroll.add(self.sidebar)

        # Separator between sidebar and content
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)

        content_hbox.pack_start(sidebar_scroll, False, False, 0)
        content_hbox.pack_start(sep, False, False, 0)
        content_hbox.pack_start(self.stack, True, True, 0)

        main_vbox.pack_start(content_hbox, True, True, 0)

        # Bottom toolbar with "Show at startup" checkbox
        bottom_sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        main_vbox.pack_start(bottom_sep, False, False, 0)

        bottom_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        bottom_bar.get_style_context().add_class("bottom-toolbar")
        bottom_bar.set_border_width(6)

        self.startup_check = Gtk.CheckButton(
            label=_("Show this dialog at startup")
        )
        self.startup_check.set_active(not os.path.exists(NORUN_FLAG))
        self.startup_check.connect("toggled", self._on_startup_toggled)
        bottom_bar.pack_start(self.startup_check, False, False, 0)

        main_vbox.pack_start(bottom_bar, False, False, 0)

        self.add(main_vbox)

        # Select first sidebar row
        first_row = self.sidebar.get_row_at_index(0)
        if first_row:
            self.sidebar.select_row(first_row)

        # Sync sidebar when stack changes (e.g. from "Let's get started" button)
        self.stack.connect("notify::visible-child-name", self._on_stack_changed)

    def _on_startup_toggled(self, check):
        """Handle the 'show at startup' checkbox."""
        if check.get_active():
            # Remove the flag file → show at startup
            try:
                if os.path.exists(NORUN_FLAG):
                    os.remove(NORUN_FLAG)
            except Exception:
                pass
        else:
            # Create the flag file → don't show at startup
            try:
                os.makedirs(CONFIG_DIR, exist_ok=True)
                with open(NORUN_FLAG, "w") as f:
                    f.write("1\n")
            except Exception:
                pass

    def _on_stack_changed(self, stack, _pspec):
        """Keep sidebar selection in sync when the stack page changes."""
        name = stack.get_visible_child_name()
        for idx, (page_id, _, _) in enumerate(PAGES):
            if page_id == name:
                row = self.sidebar.get_row_at_index(idx)
                if row:
                    self.sidebar.select_row(row)
                break


# =============================================================================
# Application
# =============================================================================


class WelcomeApp(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id=APP_ID,
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.window = None

    def do_activate(self):
        if not self.window:
            self.window = WelcomeWindow(self)
        self.window.show_all()
        self.window.present()

    def do_startup(self):
        Gtk.Application.do_startup(self)


# =============================================================================
# Entry point
# =============================================================================


def main():
    # If --norun-check is passed, exit silently if the norun flag exists.
    # Used by the autostart launcher to avoid showing the window.
    if "--norun-check" in sys.argv:
        if os.path.exists(NORUN_FLAG):
            sys.exit(0)

    app = WelcomeApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
