# syntax=docker/dockerfile:1
# Production server image for Archlast (Luanti fork with arch_base game content)

ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION} AS build-base

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    cmake \
    curl-dev \
    zlib-dev \
    zstd-dev \
    sqlite-dev \
    postgresql-dev \
    hiredis-dev \
    leveldb-dev \
    gmp-dev \
    jsoncpp-dev \
    ninja \
    linux-headers

# Build LuaJIT
WORKDIR /usr/src
RUN git clone --depth 1 --branch v2.1 https://luajit.org/git/luajit.git && \
    cd luajit && \
    make amalg && \
    make install

# Build prometheus-cpp (optional but included upstream)
RUN git clone --depth 1 --branch master https://github.com/jupp0r/prometheus-cpp.git && \
    cd prometheus-cpp && \
    cmake -B build \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_TESTING=0 \
        -GNinja && \
    cmake --build build && \
    cmake --install build

# Build libspatialindex
RUN git clone --depth 1 --branch main https://github.com/libspatialindex/libspatialindex.git && \
    cd libspatialindex && \
    cmake -B build \
        -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build build && \
    cmake --install build

FROM build-base AS engine-builder

# Copy engine source (submodule)
COPY engine/archlast-luanti /usr/src/archlast-luanti

WORKDIR /usr/src/archlast-luanti

# Configure and build Archlast engine (server-only, Release mode)
RUN cmake -B build \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SERVER=TRUE \
        -DBUILD_CLIENT=FALSE \
        -DENABLE_PROMETHEUS=FALSE \
        -DBUILD_UNITTESTS=FALSE \
        -DBUILD_BENCHMARKS=FALSE \
        -DRUN_IN_PLACE=FALSE \
        -DVERSION_EXTRA=archlast \
        -DENABLE_GETTEXT=TRUE \
        -GNinja && \
    cmake --build build --parallel $(nproc) && \
    cmake --install build

FROM alpine:${ALPINE_VERSION} AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    gmp \
    libstdc++ \
    libgcc \
    libpq \
    jsoncpp \
    zstd-libs \
    sqlite-libs \
    postgresql-libs \
    hiredis \
    leveldb \
    tini && \
    adduser -D archlast --uid 1000 -h /home/archlast && \
    mkdir -p /home/archlast/.minetest && \
    chown -R archlast:archlast /home/archlast

WORKDIR /home/archlast

# Copy built engine binaries and libraries
COPY --from=engine-builder /usr/local/bin/luantiserver /usr/local/bin/luantiserver
COPY --from=engine-builder /usr/local/lib/libspatialindex* /usr/local/lib/
COPY --from=engine-builder /usr/local/lib/libluajit* /usr/local/lib/
COPY --from=engine-builder /usr/local/share/luanti /usr/local/share/luanti

# Copy game content (arch_base)
COPY --chown=archlast:archlast game/arch_base /home/archlast/.minetest/games/archlast/game/arch_base

# Create default world directory
RUN mkdir -p /home/archlast/.minetest/world && \
    chown -R archlast:archlast /home/archlast/.minetest

# Copy example config as base
COPY --from=engine-builder /usr/local/share/doc/luanti/minetest.conf.example /etc/minetest.conf

# Default minetest.conf for dedicated server
RUN cat > /home/archlast/minetest.conf <<'EOF'
# Archlast Server Configuration
port = 30000
bind_address = 0.0.0.0
server_name = Archlast Server
server_description = Archlast Survival Sandbox RPG
max_users = 20
default_game = archlast
world = /home/archlast/.minetest/world
EOF

# Expose Luanti default ports
EXPOSE 30000/udp 30000/tcp

# Use tini for proper signal handling
USER archlast
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/luantiserver", "--config", "/home/archlast/minetest.conf"]