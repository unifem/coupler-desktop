# Builds a Docker image with OpenFOAM, Calculix and Overture, based on
# Ubuntu 17.10 for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use coupler-desktop:base as base image
FROM unifem/coupler-desktop:base
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

ADD image/home $DOCKER_HOME

USER $DOCKER_USER

ENV APlusPlus=$AXX_PREFIX/A++/install \
    XLIBS=/usr/lib/X11 \
    OpenGL=/usr \
    MOTIF=/usr \
    HDF=/usr/local/hdf5-${HDF5_VERSION} \
    Overture=$DOCKER_HOME/overture/Overture.bin \
    LAPACK=/usr/lib

# Compile Overture framework
RUN cd $DOCKER_HOME && \
    git clone --depth 1 https://github.com/unifem/overtureframework.git overture && \
    perl -e 's/https:\/\/github.com\//git@github.com:/g' -p -i $DOCKER_HOME/overture/.git/config && \
    \
    mkdir $DOCKER_HOME/cad && \
    cd overture/Overture && \
    OvertureBuild=$Overture ./buildOverture && \
    cd $Overture && \
    ./configure opt linux && \
    make -j2 && \
    make rapsodi

# Compile CG
ENV CG=$DOCKER_HOME/overture/cg
ENV CGBUILDPREFIX=$DOCKER_HOME/overture/cg.bin
RUN cd $CG && \
    make -j2 usePETSc=off libCommon && \
    make -j2 usePETSc=off cgad cgcns cgins cgasf cgsm cgmp && \
    mkdir -p $CGBUILDPREFIX/bin && \
    ln -s -f $CGBUILDPREFIX/*/bin/* $CGBUILDPREFIX/bin

RUN echo "export PATH=$Overture/bin:$CGBUILDPREFIX/bin:\$PATH:." >> \
        $DOCKER_HOME/.profile && \
    echo "export LD_LIBRARY_PATH=$APlusPlus/lib:$Overture/lib:$CG/cns/lib:$CG/ad/lib:$CG/asf/lib:$CG/ins/lib:$CG/common/lib:$CG/sm/lib:$CG/mp/lib:\$LD_LIBRARY_PATH" >> \
        $DOCKER_HOME/.profile

WORKDIR $DOCKER_HOME
USER root
