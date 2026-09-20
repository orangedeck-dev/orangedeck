# Eigenstaendige Qt-Anwendung.
#
# **Diese Datei liegt in der Wurzel und nicht in `app/`**, und das ist kein
# Geschmack: die geteilten QML-Dateien liegen unter `ui/qml/`. Von `app/` aus
# heissen sie `../ui/qml/...`, und Qt baut daraus den Namen des
# Zwischenverzeichnisses fuer den QML-Puffer. Unter Linux wird das `..`
# stillschweigend zu `_`, unter Windows nicht:
#
#     ninja: error: mkdir(.rcc/qmlcache/orangedeck-app_../ui): No such file
#
# Am 04.09.2026 im ersten CI-Lauf aufgeschlagen. **Qt empfiehlt ausdruecklich,
# QML-Dateien innerhalb des Modulverzeichnisses zu halten** -- von hier aus
# heissen sie `ui/qml/...` und die Frage stellt sich nicht mehr.
#
# Gebaut wird also aus der Wurzel:  cmake -S . -B build
cmake_minimum_required(VERSION 3.21)
project(orangedeck-app VERSION 0.2.12 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# **6.9 wegen `SafeArea`.** `app/qml/Main.qml` legt die Raender der
# Systemleisten an -- ohne die zeichnet die Anwendung ab Android 15 unter die
# Statusleiste, und die Reiter sind nicht antippbar (08.09.2026 auf einem
# Galaxy A55 gemessen). `SafeArea` gibt es erst ab QtQuick 6.9. Vorher stand
# hier 6.5 (`pragma ComponentBehavior: Bound`); eine Grenze, die nicht
# mitwandert, ist eine Behauptung.
#
# Alles, worauf gebaut wird, ist darueber: die Baustrecke holt 6.9.*, die
# Flatpak-Laufzeit hat 6.9.3, Android und dieser Rechner 6.11.2.
find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Qml Quick)
# **Hier bleibt 6.5 stehen, und zwar mit Absicht.** `REQUIRES` setzt nicht die
# Mindestfassung, sondern die Vorgaben der CMake-Regeln (etwa QTP0001 fuer den
# Ressourcenpfad der QML-Module). Sie anzuheben waere eine Aenderung am Bau,
# nicht an der Anforderung -- und die gehoert nicht in denselben Handgriff.
qt_standard_project_setup(REQUIRES 6.5)

# Freiwillig: damit wird aus dem Fenster auf Wunsch eine Layer-Shell-Flaeche
# (`--layer`), also ein Desktop-Widget oder eine Leiste. Fehlt die Bibliothek,
# faellt nur dieser Schalter weg -- unter Android gibt es sie ohnehin nicht.
if(NOT ANDROID)
    find_package(LayerShellQt QUIET)
endif()

# Fuer den Direktbezug (DirectFeed.qml, `import QtWebSockets`). Freiwillig:
# ohne das Modul faellt nur diese Betriebsart aus, der Dienst traegt weiter.
# Verlinkt wird es trotzdem, wo es da ist -- unter Android packt
# androiddeployqt nur mit, was auch gebraucht wird.
find_package(Qt6 QUIET COMPONENTS WebSockets)

# **Die ABI-Liste muss stehen, bevor das Ziel angelegt wird.** Danach ist sie
# fuer Qt leer ("The list of Android ABIs is empty"), und die Folgefehler
# lesen sich ganz anders ("not a valid android executable target"), weil aus
# dem Ziel dann eine gewoehnliche ausfuehrbare Datei statt einer Bibliothek
# wird. Der alte Baubaum hatte den Wert nur zufaellig im Puffer stehen.
if(ANDROID AND NOT QT_ANDROID_ABIS)
    set(QT_ANDROID_ABIS "${ANDROID_ABI}")
endif()

qt_add_executable(orangedeck-app app/src/main.cpp)

# Die geteilten Dateien liegen ausserhalb dieses Verzeichnisses. Ohne
# ausdruecklichen Alias landen sie mit ihrem relativen Pfad im Ressourcenbaum,
# und dann findet FeedCanvas.qml sein "mondrian.js" nicht mehr.
set(SHARED_QML
    ui/qml/FeedState.qml
    ui/qml/DirectFeed.qml
    ui/qml/DirectMiner.qml
    ui/qml/DirectMarket.qml
    ui/qml/FeedCanvas.qml
    ui/qml/FeedPanel.qml
    ui/qml/FrostedPanel.qml
    ui/qml/ClockView.qml
    ui/qml/MinerView.qml
    ui/qml/MinerChart.qml
    ui/qml/NetworkView.qml
    ui/qml/NetworkChart.qml
    ui/qml/PriceChart.qml
    ui/qml/MarketView.qml
    ui/qml/MarketLiq.qml
    ui/qml/MarketHeat.qml
    ui/qml/DropDown.qml
    ui/qml/ViewTabs.qml
    ui/qml/FeedTabs.qml
    ui/qml/InfoPopup.qml
    ui/qml/ExplorerView.qml
    ui/qml/TxFlow.qml
    ui/qml/CopyButton.qml
    ui/qml/BlockChain.qml
    ui/qml/BlockCard.qml
    ui/qml/BlockTiles.qml
    ui/qml/ProjectedBlock.qml
    ui/qml/TileGoggles.qml
    ui/qml/WatchView.qml
    ui/qml/TxList.qml
    ui/qml/BlockHistory.qml
    ui/qml/SettingsView.qml
    ui/qml/ExplorerHome.qml
    ui/qml/MainPanels.qml
    ui/qml/search.js
    ui/qml/txtype.js
    ui/qml/money.js
    ui/qml/roll.js
    ui/qml/strings.js
    ui/qml/views.js
    ui/qml/mondrian.js
    ui/qml/colors.js
    ui/qml/fonts.js
)
# Main.qml gehoert dazu: liegt es im Ressourcenbaum unter qml/, waehrend die
# geteilten Dateien in der Modulwurzel sitzen, findet es sie nicht mehr
# ("FeedState is not a type"). Die Aliasse muessen VOR qt_add_qml_module
# gesetzt werden, danach wirken sie nicht mehr.
foreach(f ${SHARED_QML} app/qml/Main.qml)
    get_filename_component(n "${f}" NAME)
    set_source_files_properties("${f}" PROPERTIES QT_RESOURCE_ALIAS "${n}")
endforeach()

qt_add_qml_module(orangedeck-app
    URI OrangeDeck
    VERSION 1.0
    QML_FILES app/qml/Main.qml ${SHARED_QML}
)

# **Das Fenstersymbol gehoert in die Anwendung.** Unter Wayland reicht die
# app_id samt .desktop-Datei; unter X11 und XWayland traegt das Fenster sein
# Symbol selbst (`_NET_WM_ICON`), und ohne dieses Bild bleibt es leer --
# gemessen am 20.09.2026 im Xvfb. Erzeugt wird es von tools/symbole.py aus
# demselben SVG wie alle anderen Symbole.
qt_add_resources(orangedeck-app "symbol"
    PREFIX "/"
    FILES app/icons/dev.orangedeck.OrangeDeck-256.png
)

# **Ohne das gibt es auf Windows ein Konsolenfenster neben der Anwendung und
# auf macOS gar kein .app-Buendel** -- dann laesst sie sich dort weder
# doppelklicken noch mit `macdeployqt` packen. Unter Linux und Android sind
# beide Eigenschaften wirkungslos, sie kosten also nichts.
#
# Aufgefallen am 04.09.2026 beim Schreiben der Bauplaene fuer Windows und
# macOS -- auf diesem Rechner konnte es nie stoeren.
set_target_properties(orangedeck-app PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE ON
)

target_link_libraries(orangedeck-app PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)

# **Die Fassung steht an genau einer Stelle.** Sie stand vorher als "0.1" in
# main.cpp und als Zahl in `project()` -- zwei Stellen, die auseinanderlaufen,
# sobald eine gepflegt wird und die andere nicht. Genau das war am 05.09.2026
# passiert.
target_compile_definitions(orangedeck-app PRIVATE
    ORANGEDECK_VERSION="${PROJECT_VERSION}")

# **Auf Android muss OpenSSL mit ins APK.** Qt liefert es dort nicht mit, und
# ohne es meldet das Geraet nur "No functional TLS backend was found" -- die
# App ist dann vollstaendig funktionslos, weil mempool.space nur https und wss
# spricht. Auf dem Schreibtisch faellt das nicht auf: dort wird das
# System-OpenSSL benutzt.
#
# Gebaut wird es mit `tools/openssl-android.sh` aus dem offiziellen Quelltext,
# Pruefsumme gegen die Angabe des Projekts. Das Ergebnis liegt ausserhalb des
# Repos; fehlt es, wird trotzdem gebaut -- nur eben ohne TLS, und diese
# Meldung sagt es.
if(ANDROID)
    # **Eigenes Paketverzeichnis statt Qts Vorlage.** Ohne das erzeugt
    # androiddeployqt ein Manifest mit dem Paketnamen
    # `org.qtproject.example.orangedeck_app` und der Beschriftung
    # `orangedeck-app` -- Qts Beispielwerte, die das APK bis zum 05.09.2026
    # wirklich trug. Hier liegen jetzt der eigene Name, die Beschriftung und
    # die Verknuepfungen je Ansicht.
    set_property(TARGET orangedeck-app PROPERTY
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")

    # **Die Bibliotheken gepackt, nicht roh.** Ohne das legt Gradle ab
    # minSdk 23 jede .so ungepackt ins APK, damit Android sie direkt aus der
    # Datei laden kann. Bei uns sind das 50 von 57 MB. Gepackt sind es rund
    # 20 MB -- nachgerechnet am 19.09.2026 am APK von 0.2.11. Jeder Download
    # wird kleiner, auch aus dem eigenen F-Droid-Repo (tools/fdroid-repo.sh),
    # und tools/apk.sh meldet, wenn es wieder waechst. Der Preis: Android entpackt die
    # Bibliotheken bei der Installation, die App belegt danach etwas mehr
    # Platz auf dem Telefon.
    set_property(TARGET orangedeck-app PROPERTY QT_ANDROID_LEGACY_PACKAGING ON)

    # **Die Fassung steht im Manifest, und das ist hier nicht zu aendern.**
    # `QT_ANDROID_VERSION_NAME` und `..._CODE` wurden versucht: bei einem
    # eigenen `QT_ANDROID_PACKAGE_SOURCE_DIR` setzt androiddeployqt sie
    # **nicht** durch -- das gebaute APK meldete weiter die alte Zahl. Eine
    # Einstellung, die stillschweigend nichts tut, ist schlimmer als keine.
    #
    # Also die zweite Stelle nicht wegdefinieren, sondern laut bewachen: das
    # Manifest muss dieselbe Fassung nennen wie `project()`, sonst bricht das
    # Einrichten ab. Genau diese Drift liess heute frueh den Bauplan dreizehn
    # Commits zurueckstehen -- dort hat sie niemand bemerkt.
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/android/AndroidManifest.xml" _manifest)
    string(REGEX MATCH "android:versionName=\"([^\"]*)\"" _ "${_manifest}")
    if(NOT CMAKE_MATCH_1 STREQUAL PROJECT_VERSION)
        message(FATAL_ERROR
            "android/AndroidManifest.xml nennt die Fassung ${CMAKE_MATCH_1}, "
            "project() aber ${PROJECT_VERSION}. Beide muessen uebereinstimmen; "
            "androiddeployqt zieht den Wert bei eigenem Manifest nicht nach.")
    endif()

    set(_ossl "${CMAKE_CURRENT_SOURCE_DIR}/build-openssl-android/${ANDROID_ABI}")
    # Die Namen sind nicht frei waehlbar: Qts TLS-Plugin sucht auf Android
    # nach `libssl_3.so` und `libcrypto_3.so` (Vorgabe von
    # `ANDROID_OPENSSL_SUFFIX`). Heissen sie anders, findet es sie nicht --
    # auch wenn sie im APK liegen.
    if(EXISTS "${_ossl}/libssl_3.so" AND EXISTS "${_ossl}/libcrypto_3.so")
        set_property(TARGET orangedeck-app APPEND PROPERTY QT_ANDROID_EXTRA_LIBS
            "${_ossl}/libcrypto_3.so" "${_ossl}/libssl_3.so")
        message(STATUS "orangedeck: OpenSSL fuer ${ANDROID_ABI} wird mitgepackt")
    else()
        message(WARNING
            "orangedeck: kein OpenSSL fuer ${ANDROID_ABI} -- das APK bekommt "
            "KEIN TLS und ist auf dem Geraet unbrauchbar. Bauen mit:\n"
            "    tools/openssl-android.sh ${ANDROID_ABI}")
    endif()
endif()

if(Qt6WebSockets_FOUND)
    target_link_libraries(orangedeck-app PRIVATE Qt6::WebSockets)
    message(STATUS "orangedeck: QtWebSockets vorhanden, Direktbezug steht bereit")
else()
    message(STATUS "orangedeck: ohne QtWebSockets gebaut, nur Betrieb ueber den Dienst")
endif()

if(LayerShellQt_FOUND)
    target_compile_definitions(orangedeck-app PRIVATE ORANGEDECK_LAYERSHELL)
    target_link_libraries(orangedeck-app PRIVATE LayerShellQt::Interface)
    message(STATUS "orangedeck: Layer-Shell vorhanden, --layer steht bereit")
else()
    message(STATUS "orangedeck: ohne Layer-Shell gebaut, --layer fehlt")
endif()

include(GNUInstallDirs)
# Auf Android ist "orangedeck-app" keine ausfuehrbare Datei, sondern eine
# Bibliothek, die die Java-Huelle laedt -- `install(TARGETS)` verlangt dort
# ein LIBRARY-Ziel und bricht sonst schon beim Einrichten ab. Installiert wird
# unter Android ohnehin nichts: das Ergebnis ist das APK.
# **Nur dort, wo es ein freedesktop-System gibt.** Die .desktop-Datei und das
# Symbol im hicolor-Baum sind Linux-Begriffe; auf macOS kaeme dazu, dass ein
# `MACOSX_BUNDLE`-Ziel bei `install(TARGETS)` ein BUNDLE-Ziel verlangt und
# sonst schon beim Einrichten abbricht.
if(NOT ANDROID AND NOT APPLE AND NOT WIN32)
    install(TARGETS orangedeck-app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/app/dev.orangedeck.OrangeDeck.desktop
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/app/icons/dev.orangedeck.OrangeDeck.svg
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)
endif()
