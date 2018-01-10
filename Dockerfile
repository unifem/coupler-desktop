# Builds a Docker image with OpenFOAM, Calculix and Overture, based on
# Ubuntu 17.10 for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use coupler-desktop:framework as base image
FROM unifem/coupler-desktop:framework
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

ADD image/home $DOCKER_HOME

USER $DOCKER_USER

# Compile CG in parallel
ENV APlusPlus=$PXX_PREFIX/P++/install \
    PPlusPlus=$PXX_PREFIX/P++/install \
    HDF=/usr/local/hdf5-${HDF5_VERSION}-openmpi \
    Overture=$DOCKER_HOME/overture/Overture.par \
    PETSC_DIR=/usr/lib/petscdir/3.7.6/x86_64-linux-gnu-real \
    PETSC_LIB=/usr/lib/x86_64-linux-gnu \
    CG=$DOCKER_HOME/overture/cg \
    CGBUILDPREFIX=$DOCKER_HOME/overture/cg.bin

RUN cd $CG && \
    make -j2 usePETSc=on OV_USE_PETSC_3=1 libCommon && \
    make -j2 usePETSc=on OV_USE_PETSC_3=1 cgad cgcns cgins cgasf cgsm cgmp && \
    mkdir -p $CGBUILDPREFIX/bin && \
    ln -s -f $CGBUILDPREFIX/*/bin/* $CGBUILDPREFIX/bin

RUN echo "export PATH=$CGBUILDPREFIX/bin:\$PATH:." >> \
        $DOCKER_HOME/.profile

USER root
WORKDIR $DOCKER_HOME
