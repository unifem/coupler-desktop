# Builds a Docker image with OpenFOAM, Calculix and Overture, based on
# Ubuntu 17.10 for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use openfoam-ccx as base image
FROM unifem/openfoam-ccx:latest
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

ADD image/home $DOCKER_HOME

# Install compilers, openmpi, motif and mesa to prepare for Overture
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      csh \
      build-essential \
      gfortran \
      openmpi-bin \
      libopenmpi-dev \
      \
      libmotif-dev \
      libgl1-mesa-dev \
      libglu1-mesa \
      libglu1-mesa-dev \
      \
      libperl-dev \
      \
      libxmu-dev \
      libxi-dev \
      x11proto-print-dev \
      \
      liblapack3 \
      liblapack-dev && \
    \
    curl -O http://ubuntu.cs.utah.edu/ubuntu/pool/main/libx/libxp/libxp6_1.0.2-1ubuntu1_amd64.deb && \
    dpkg -i libxp6_1.0.2-1ubuntu1_amd64.deb && \
    curl -O http://ubuntu.cs.utah.edu/ubuntu/pool/main/libx/libxp/libxp-dev_1.0.2-1ubuntu1_amd64.deb && \
    dpkg -i libxp-dev_1.0.2-1ubuntu1_amd64.deb && \
    \
    ln -s -f /usr/bin/make /usr/bin/gmake && \
    \
    ln -s -f /usr/lib/x86_64-linux-gnu /usr/lib64 && \
    ln -s -f /usr/lib/x86_64-linux-gnu/libX11.so /usr/lib/X11 && \
    \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


USER $DOCKER_USER
WORKDIR $DOCKER_HOME
ENV AXX_PREFIX=$DOCKER_HOME/overture/A++P++.bin

# Download Overture, A++ and P++; compile only A++
# Do not run "make check" to avoid timeout
RUN cd $DOCKER_HOME && \
    git clone --depth 1 https://github.com/unifem/overtureframework.git overture && \
    perl -e 's/https:\/\/github.com\//git\@github.com:/g' -p -i $DOCKER_HOME/overture/.git/config && \
    cd $DOCKER_HOME/overture && \
    cd A++P++ && \
    ./configure --enable-SHARED_LIBS --prefix=$AXX_PREFIX && \
    make -j2 && \
    make install

# Compile Overture framework
WORKDIR $DOCKER_HOME/overture

ENV APlusPlus=$AXX_PREFIX/A++/install \
    XLIBS=/usr/lib/X11 \
    OpenGL=/usr \
    MOTIF=/usr \
    HDF=/usr/local/hdf5-${HDF5_VERSION} \
    Overture=$DOCKER_HOME/overture/Overture.bin \
    LAPACK=/usr/lib

RUN cd $DOCKER_HOME/overture/Overture && \
    mkdir $DOCKER_HOME/cad && \
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
