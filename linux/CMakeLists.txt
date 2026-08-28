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

    resources/app_icon.svg
    resources/icon.qrc
)

target_include_directories(tick PRIVATE src)
target_link_libraries(tick PRIVATE Qt6::Widgets Qt6::Network Qt6::Sql)

install(TARGETS tick RUNTIME DESTINATION bin)