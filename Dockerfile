FROM almalinux:9 AS builder
RUN dnf -y update && \
    dnf -y install \
    gcc \
    gcc-c++ \
    cmake \
    git \
    make \
    elfutils-libelf-devel \
    elfutils-devel \
    autoconf \
    automake \
    libtool \
    libzstd-devel \
    libarchive \
    bzip2-devel \
    xz-devel \
    zlib-devel \
    gettext-devel \
    flex \
    bison \
    gawk \
    libcurl-devel \
    && dnf clean all

WORKDIR /app
COPY . .
RUN mkdir build-docker && cd build-docker && cmake -DWITH_SYSTEM_ELFUTILS=OFF .. && make

FROM almalinux:9
RUN dnf -y update && \
    dnf -y install \
    libstdc++ \
    && dnf clean all

COPY --from=builder /app/build-docker/unwindpmp /usr/local/bin/unwindpmp

ENV DEBUGINFOD_URLS https://debuginfod.elfutils.org/
ENV DEBUGINFOD_PROGRESS 1

ENTRYPOINT ["/usr/local/bin/unwindpmp"]

