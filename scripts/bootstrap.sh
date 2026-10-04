#!/usr/bin/env bash
set -euo pipefail

echo "=== Archlast Bootstrap ==="
echo "Detecting package manager..."

if command -v pacman &>/dev/null; then
    echo "Arch-based system detected."
    sudo pacman -Sy --needed --noconfirm \
        base-devel libcurl-gnutls cmake libpng libjpeg-turbo sqlite \
        libogg libvorbis openal freetype2 jsoncpp gmp luajit leveldb \
        ncurses zstd gettext sdl2 libzip
elif command -v dnf &>/dev/null; then
    echo "Fedora/RHEL system detected."
    sudo dnf install -y \
        gcc-c++ make cmake libcurl-devel libpng-devel libjpeg-turbo-devel \
        sqlite-devel libogg-devel libvorbis-devel openal-soft-devel \
        freetype-devel jsoncpp-devel gmp-devel luajit-devel leveldb-devel \
        ncurses-devel libzstd-devel gettext SDL2-devel libzip-devel
elif command -v apt-get &>/dev/null; then
    echo "Debian/Ubuntu system detected."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential cmake libcurl4-gnutls-dev libpng-dev libjpeg-dev \
        libsqlite3-dev libogg-dev libvorbis-dev libopenal-dev libfreetype6-dev \
        libjsoncpp-dev libgmp-dev libluajit-5.1-dev libleveldb-dev \
        libncurses-dev libzstd-dev gettext libsdl2-dev libzip-dev
else
    echo "ERROR: Unsupported package manager. Install deps manually per doc/compiling/linux.md"
    exit 1
fi

echo ""
echo "=== Tool Versions ==="
git --version
cmake --version | head -1
g++ --version | head -1
echo ""
echo "Bootstrap complete."
