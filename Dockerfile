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

################################################################################

FROM almalinux:9-minimal

RUN microdnf --nodocs -y update && \
    microdnf --nodocs -y install \
    libstdc++ \
    libzstd \
    zlib \
    bzip2-libs \
    xz-libs \
    && microdnf clean all

COPY --from=builder /app/build-docker/unwindpmp /usr/sbin/unwindpmp
COPY --from=builder /app/build-docker/elfutils/lib/ /usr/lib/
RUN ldconfig

ENV DEBUGINFOD_URLS https://debuginfod.elfutils.org/
ENV DEBUGINFOD_PROGRESS 1
ENV DEBUGINFOD_VERBOSE 1
ENTRYPOINT ["/usr/sbin/unwindpmp"]
