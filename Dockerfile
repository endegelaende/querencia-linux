# =============================================================================
# Querencia Linux
# "Where Linux Feels at Home"
# Atomic Desktop with MATE | AlmaLinux 10 | GPU Support (AMD / NVIDIA)
# =============================================================================
# Based on the AlmaLinux Atomic Respin Template
# https://github.com/AlmaLinux/atomic-respin-template
# =============================================================================

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx

COPY files/system /system_files/
COPY --chmod=0755 files/scripts /build_files/
COPY *.pub /keys/
COPY assets /assets/

# Base Image: AlmaLinux 10 bootc (no desktop -- we add MATE ourselves)
FROM quay.io/almalinuxorg/almalinux-bootc:10

ARG IMAGE_NAME
ARG IMAGE_REGISTRY
ARG VARIANT
ENV VARIANT=${VARIANT}

# OCI Image Metadata
LABEL org.opencontainers.image.title="Querencia Linux"
LABEL org.opencontainers.image.description="Querencia Linux -- Atomic Desktop with MATE, GPU Support, Multimedia Codecs and Micromamba (AlmaLinux 10)"
LABEL org.opencontainers.image.source="https://github.com/endegelaende/querencia-linux"
LABEL org.opencontainers.image.vendor="endegelaende"
LABEL org.opencontainers.image.version="10"
LABEL ostree.bootable="true"

RUN --mount=type=cache,dst=/var/cache/dnf \
    --mount=type=tmpfs,dst=/opt \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build_files/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
