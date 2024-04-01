ARG BASE_IMAGE
FROM ${BASE_IMAGE} as builder

# Install deps.
RUN set -xe; \
    #dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y \
        cmake automake clang-15 bison flex libfuse-dev libudev-dev pkg-config libc6-dev-i386 \
gcc-multilib libcairo2-dev libgl1-mesa-dev curl libglu1-mesa-dev libtiff5-dev \
libfreetype6-dev git git-lfs libelf-dev libxml2-dev libegl1-mesa-dev libfontconfig1-dev \
libbsd-dev libxrandr-dev libxcursor-dev libgif-dev libavutil-dev libpulse-dev \
libavformat-dev libavcodec-dev libswresample-dev libdbus-1-dev libxkbfile-dev \
libssl-dev libstdc++-12-dev \
    libcap2-bin python2;
    #rm -rf /var/lib/apt/lists/*;

# Clone Darling
ARG DARLING_GIT_REF="master"
RUN set -xe; \
    mkdir -p /usr/local/src; \
    git clone --recurse-submodules https://github.com/darlinghq/darling.git /usr/local/src/darling;

WORKDIR /usr/local/src/darling

# Checkout working gitref
RUN set -xe; \
    git lfs install; \
    git checkout ${DARLING_GIT_REF}; \
    git submodule update --recursive; \
    mkdir -p /usr/local/src/darling/build;

# Set our working directory to the build dir
WORKDIR /usr/local/src/darling/build

# Configure Darling Build
RUN set -xe; \
    cmake -DTARGET_i386=OFF -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..;

# Build Darling
RUN set -xe; \
    make -j$(getconf _NPROCESSORS_ONLN);

# Install Darling    
RUN set -xe; \
    make install; 

#RUN set -xe; \
#    cp /usr/local/src/darling/build/src/startup/rtsig.h /usr/local/src/darling/rtsig.h ;\
#    mkdir -p /usr/local/src/darling/build/src/startup; \
#    mv /usr/local/src/darling/rtsig.h /usr/local/src/darling/src/startup/rtsig.h; \

# Copy the modified CMakeLists.txt used for building LKM
#COPY build-assets /

# Move LKM dependencies into single location
# RUN set -xe; \
#     cd /usr/local/src/; \
#     rm -rf darling/build; \
#     mv darling darling-full; \
#     mkdir -p darling/src; \
#     mkdir -p darling/build/src; \
#     mv /usr/local/src/docker-darling/CMakeLists.txt /usr/local/src/darling/CMakeLists.txt ;\
#     mv /usr/local/src/darling-full/src/lkm /usr/local/src/darling/src/lkm ;\
#     mv /usr/local/src/darling-full/cmake /usr/local/src/darling/cmake; \
#     mv /usr/local/src/darling-full/src/bootstrap_cmds /usr/local/src/darling/src/bootstrap_cmds; \
#     mv /usr/local/src/darling-full/platform-include /usr/local/src/darling/platform-include; \
#     mv /usr/local/src/darling-full/kernel-include /usr/local/src/darling/kernel-include; \
#     mv /usr/local/src/darling-full/src/CMakeLists.txt /usr/local/src/darling/src/CMakeLists.txt; \
#     mv /usr/local/src/darling-full/src/startup /usr/local/src/darling/build/src/startup; \
#     rm -rf /usr/local/src/darling-full; \
#     rm -rf /usr/local/src/docker-darling; \
#     cd /usr/local/src/darling/build; \
#     cmake ..;

# Copy our runtime assets
COPY ./runtime-assets/ /

# Create final runtime image
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Create our group & user.
RUN set -xe; \
    groupadd -g 1000 darling; \
    useradd -g darling -u 1000 -s /bin/sh -d /home/darling darling; \
    # Install deps. \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y \
        bison \
        clang \
        cmake \
        flex \
        kmod \
        make \
        sudo \
        libegl-dev libxrandr-dev; \
    rm -rf /var/lib/apt/lists/*; \
    # Setup sudo access \
    echo "darling ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers;

# Copy our Darling build from previous stage
COPY --from=builder /usr/local /usr/local

# Labels / Metadata.
ARG BUILD_DATE
ARG DARLING_GIT_REF
ARG VCS_REF
ARG VERSION
LABEL \
    org.opencontainers.image.authors="James Brink <brink.james@gmail.com>" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.description="Darling ($VERSION)" \
    org.opencontainers.image.revision="${VCS_REF}" \
    org.opencontainers.image.source="https://github.com/utensils/docker-darling.git" \
    org.opencontainers.image.title="darling (lite)" \
    org.opencontainers.image.vendor="Utensils" \
    org.opencontainers.image.version="git - ${DARLING_GIT_REF}"

# Setup our environment variables.
ENV PATH="/usr/local/bin:$PATH"

# Drop down to our unprivileged user.
USER darling

# Set our working directory.
WORKDIR /home/darling

# Set the entrypoint.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set the default command
CMD ["/usr/local/bin/darling", "shell"]
