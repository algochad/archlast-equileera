# Archlast Linux installers

Three formats, one Release engine + `arch_base` game (`5.17.0-archlast`).

## Quick start

| Format | Build | Install |
|---|---|---|
| Arch | `makepkg -si` in `packaging/arch/` (or AUR) | `sudo pacman -U archlast-*.pkg.tar.zst` |
| Debian/Ubuntu | `packaging/deb/build-deb-docker.sh` (needs docker) | `sudo apt install ./dist/archlast-*-amd64.deb` |
| Portable | `packaging/appimage/build-appimage.sh` | extract `dist/*-appdir.tar.zst`, run `AppDir/AppRun` (or `.AppImage` if appimagetool present) |

Run: `archlast --gameid arch_base` · server: `archlast-server --gameid arch_base --world <path>`.

## Files

- `packaging/package-linux.sh` — shared Release stage (`dist/stage/` + `dist/*.tar.zst`).
  Extra dep prefix: `CMAKE_PREFIX_PATH=/path/to/prefix`.
- `packaging/arch/PKGBUILD` + `archlast.desktop` — AUR-style source package.
- `packaging/deb/build-deb.sh` — assembles `.deb` from `dist/stage` (same-distro reuse only).
- `packaging/deb/build-deb-docker.sh` + `Dockerfile.build` — **correct** Debian path:
  compiles inside `debian:trixie-slim` so ABIs (jsoncpp, curl, …) match.
- `packaging/appimage/build-appimage.sh` — AppDir with bundled `.so`s.
  Non-system deps: `EXTRA_LIB_DIRS=/path/to/lib`.

## Verified

- Arch Release: `RUN_IN_PLACE=0`, all backends on, `arch_base` headless boot clean.
- Debian `.deb`: `apt install` OK on trixie-slim, `--version` + `arch_base` boot verified in-container.
- AppDir: `AppRun --version`, `--gameid list`, and `archlast-server` headless boot all pass.

## Notes

- Upstream `ENABLE_X=TRUE` only *warns* when a backend lib is missing — all builders
  assert `USE_LEVELDB/USE_REDIS/USE_SPATIAL/USE_POSTGRESQL=1` post-configure.
- Never repackage an Arch-built stage as `.deb`: `libjsoncpp.so.27` (Arch) vs `.so.26`
  (trixie) breaks at load. Use the docker builder for Debian.
- `leveldb` static archives must not reference snappy unless linked; the local
  throwaway copy in `/tmp` is not part of this repo.
