# Builds a Docker image with OpenFOAM, Calculix and Overture, based on
# Ubuntu 17.10 for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use mapper-desktop as base image
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

# Download Overture, A++ and P++; compile A++
ENV APlusPlus_VERSION=0.8.2
RUN cd $DOCKER_HOME && \
    git clone --depth 1 https://github.com/unifem/overtureframework.git overture && \
    cd $DOCKER_HOME/overture && \
    curl -L http://overtureframework.org/software/AP-$APlusPlus_VERSION.tar.gz | tar zx && \
    cd A++P++-$APlusPlus_VERSION && \
    ./configure --enable-SHARED_LIBS --prefix=`pwd` && \
    make -j2 && \
    make install

# Compile Overture framework
WORKDIR $DOCKER_HOME/overture
ENV OVERTURE_VERSION=v26sf

ENV APlusPlus=$DOCKER_HOME/overture/A++P++-${APlusPlus_VERSION}/A++/install \
    XLIBS=/usr/lib/X11 \
    OpenGL=/usr \
    MOTIF=/usr \
    HDF=/usr/local/hdf5-${HDF5_VERSION} \
    Overture=$DOCKER_HOME/overture/Overture.${OVERTURE_VERSION} \
    LAPACK=/usr/lib

RUN cd $DOCKER_HOME/overture/Overture && \
    mkdir $DOCKER_HOME/cad && \
    OvertureBuild=$Overture ./buildOverture && \
    cd $Overture && \
    ./configure opt linux && \
    make -j2 && \
    make rapsodi

# Compile CG
ENV CG_VERSION=$OVERTURE_VERSION
ENV CG=$DOCKER_HOME/overture/cg.$CG_VERSION
RUN mv $DOCKER_HOME/overture/cg $CG && \
    cd $CG && \
    make -j2 usePETSc=off libCommon && \
    make -j2 usePETSc=off cgad cgcns cgins cgasf cgsm cgmp && \
    mkdir -p $CG/bin && \
    ln -s -f $CG/*/bin/* $CG/bin

RUN echo "export PATH=$Overture/bin:$CG/bin:\$PATH:." >> \
        $DOCKER_HOME/.profile

WORKDIR $DOCKER_HOME
USER root
