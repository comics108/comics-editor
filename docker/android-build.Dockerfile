# sdd-comics-editor-build: тулчейн-образ для верификационной сборки Android
# (Comics Editor v2.9) — Flutter + Gradle. NDK не устанавливается: Android
# больше не использует NativeAOT (см. sdd-comics-editor-v2.9-android-ios —
# пивот на DartIoCore, чистый Dart, без нативных C#-библиотек на мобильных).
#
# Образ содержит только тулчейн, без исходников: код монтируется при `docker run`
# (см. tool/docker-build.sh, .github/workflows/build.yml).
#
# Версии зафиксированы вручную (см. flows/sdd-comics-editor-build/_status.md,
# раздел Pinned Versions) — держать в синхроне с build.yml при апдейте.

FROM ubuntu:24.04

# TARGETARCH — встроенный buildx-арг (amd64/arm64/...), подставляется автоматически
# по --platform; используется ниже для JAVA_HOME (Adoptium ставит архитектурно-
# специфичный путь) — без этого Dockerfile работал бы только на одной архитектуре.
ARG TARGETARCH
ARG FLUTTER_VERSION=3.44.6
ARG CMDLINE_TOOLS_BUILD=9862592
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git unzip xz-utils gnupg wget \
    && rm -rf /var/lib/apt/lists/*

# Eclipse Temurin JDK 17 — официальный Adoptium APT-репозиторий (не generic
# openjdk-17-jdk), для точного соответствия actions/setup-java distribution: temurin.
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
        -o /etc/apt/keyrings/adoptium.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb noble main" \
        > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update && apt-get install -y --no-install-recommends temurin-17-jdk \
    && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-${TARGETARCH}
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Android SDK: только platform-tools + один платформенный API + build-tools —
# ровно то, что нужно `flutter build apk`. commandlinetools-linux zip-версия
# зафиксирована по сборке (проверена вручную через repository2-3.xml Google).
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip" \
        -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
# `yes | sdkmanager --licenses` может завершиться ненулевым кодом при закрытии
# пайпа после последней лицензии (SIGPIPE-подобное поведение под non-tty) — это
# не сбой приёма лицензий, поэтому не связываем через &&, а проверяем отдельно.
RUN yes | sdkmanager --licenses; \
    sdkmanager --install "platform-tools" "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}"

# Flutter SDK — тот же официальный дистрибутив, что скачивает subosito/flutter-action.
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
        -o /tmp/flutter.tar.xz \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"

RUN git config --global --add safe.directory '*' \
    && flutter config --no-analytics --no-enable-linux-desktop \
    && flutter precache --android \
    && flutter --version

WORKDIR /workspace
