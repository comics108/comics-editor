# sdd-comics-editor-build: тулчейн-образ для верификационной сборки Linux desktop
# (Comics Editor v2.9) — Flutter linux desktop + headless C#-ядро.
#
# Образ содержит только тулчейн, без исходников: код монтируется при `docker run`
# (см. tool/docker-build.sh, .github/workflows/build.yml). Пересобирать нужно
# только при смене версий тулчейна.
#
# Версии зафиксированы вручную (см. flows/sdd-comics-editor-build/_status.md,
# раздел Pinned Versions) — держать в синхроне с build.yml при апдейте.

FROM ubuntu:24.04

ARG FLUTTER_VERSION=3.44.6
ARG DOTNET_VERSION=10.0.302

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git unzip xz-utils \
        clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# .NET SDK — точная версия (не floating), см. dotnet-install.sh --version.
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && bash /tmp/dotnet-install.sh --version "${DOTNET_VERSION}" --install-dir /usr/share/dotnet \
    && rm /tmp/dotnet-install.sh
ENV PATH="/usr/share/dotnet:${PATH}" \
    DOTNET_ROOT=/usr/share/dotnet \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# Flutter SDK — тот же официальный дистрибутив, что скачивает subosito/flutter-action.
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
        -o /tmp/flutter.tar.xz \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"

RUN git config --system --add safe.directory '*' \
    && flutter config --no-analytics --enable-linux-desktop \
    && flutter precache --linux \
    && flutter --version

# Локально контейнер запускается от UID хоста (tool/docker-build.sh), чтобы
# артефакты сборки на bind-mounted /workspace не были root-owned — поэтому
# тулчейн, собранный на этапе build от root, должен быть доступен на запись
# любому пользователю (Flutter пишет кэш-файлы в свой каталог при каждом запуске).
RUN chmod -R a+rwX /opt/flutter /usr/share/dotnet

WORKDIR /workspace
