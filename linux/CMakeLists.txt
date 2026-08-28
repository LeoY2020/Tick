cmake_minimum_required(VERSION 3.16)

project(Tick VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets Network Sql)

# 数据库驱动（QUuid 需要 Core 即可，其余由组件传递）
add_executable(tick WIN32
    src/main.cpp

    src/data/database.cpp
    src/data/goalrepository.cpp
    src/data/taskrepository.cpp
    src/data/settingsrepository.cpp
    src/data/chatrepository.cpp

    src/domain/progressengine.cpp

    src/services/aiservice.cpp
    src/services/documenttextextractor.cpp
    src/services/notificationservice.cpp
    src/services/jsonbackup.cpp

    src/ui/mainwindow.cpp
    src/ui/goaldialog.cpp
    src/ui/taskdialog.cpp
    src/ui/settingsdialog.cpp
    src/ui/aichatdialog.cpp
    src/ui/translation.cpp
    src/ui/theme.cpp

    resources/app_icon.png
    resources/icon.qrc
)

target_include_directories(tick PRIVATE src)
target_link_libraries(tick PRIVATE Qt6::Widgets Qt6::Network Qt6::Sql)

# ---- 安装规则 ----
install(TARGETS tick RUNTIME DESTINATION bin)
install(FILES resources/app_icon.png
        DESTINATION share/pixmaps
        RENAME tick.png)
install(FILES packaging/tick.desktop
        DESTINATION share/applications)

# ---- 安装包（deb / rpm / 通用 tar.gz）----
set(CPACK_PACKAGE_NAME "tick")
set(CPACK_PACKAGE_VERSION "1.0.0")
set(CPACK_PACKAGE_VENDOR "Tick")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Tick todo application")
set(CPACK_PACKAGE_EXECUTABLES "tick" "Tick")
set(CPACK_CREATE_DESKTOP_LINKS "tick")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "qt6-base")
set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtbase")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Productivity")
set(CPACK_RPM_PACKAGE_DESCRIPTION "Tick todo application")
set(CPACK_STRIP_FILES "bin/tick")
set(CPACK_GENERATOR "DEB;RPM;TGZ")
include(CPack)