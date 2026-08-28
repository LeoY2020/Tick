# RPM spec for Tick (reference packaging for Red Hat / Fedora / CentOS)
# Builds from the linux/ source tree (CMake). Adjust Source0 to your tarball
# name/location if you package a release archive instead of building in-place.
Name:           tick
Version:        1.0.0
Release:        1%{?dist}
Summary:        Tick — goal-based infinite-task-tree todo application
License:        MIT
URL:            https://example.invalid/tick
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake >= 3.16
BuildRequires:  qt6-qtbase-devel
BuildRequires:  ninja-build

Requires:       qt6-qtbase
Requires:       qt6-qtbase-sql
Requires:       qt6-qtsvg
Recommends:     poppler-utils

%description
Cross-platform todo app that organizes todos around Goals with an
unlimited-level task tree, recursive progress aggregation, local reminders
and an optional OpenAI-compatible AI assistant. This is the Qt6/Widgets
desktop build for RPM-based distributions.

%prep
%autosetup -n %{name}-%{version}

%build
%cmake -B build -DCMAKE_BUILD_TYPE=Release -G Ninja
%cmake_build

%install
%cmake_install

%files
%{_bindir}/tick

%changelog
* Thu Aug 28 2026 Tick Developers <tick@example.com> - 1.0.0-1
- Initial release of the Linux (Qt6) build.