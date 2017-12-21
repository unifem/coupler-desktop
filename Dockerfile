# Builds a Docker image with sfepy and Calculix, based on
# Ubuntu 17.10 for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use mapper-desktop as base image
FROM unifem/mapper-desktop:latest
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

# Install gmsh, freecad, calculix
RUN add-apt-repository ppa:nschloe/gmsh-backports && \
    add-apt-repository ppa:freecad-maintainers/freecad-stable && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        gmsh \
        freecad \
        calculix-ccx \
        libsuitesparse-dev && \
    apt-get clean && \
    pip3 install -U \
        cython \
        pyparsing \
        scikit-umfpack \
        tables \
        pymetis \
        pyamg \
        pyface && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Install sfepy (without pysparse and mayavi are not installed)
ARG SFEPY_VERSION=2017.3
ARG HDF5_VERSION=1.8.20

RUN pip3 install --no-cache-dir \
        https://bitbucket.org/dalcinl/igakit/get/default.tar.gz && \
    pip3 install --no-cache-dir \
        https://github.com/sfepy/sfepy/archive/release_${SFEPY_VERSION}.tar.gz

ADD image/home $DOCKER_HOME

# Install compilers, openmpi, motif, mesa, and hdf5 to prepare for overture
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
    ln -s -f /usr/lib/x86_64-linux-gnu/libX11.so /usr/lib/X11 && \
    cd /tmp && \
    curl -L https://support.hdfgroup.org/ftp/HDF5/current18/src/hdf5-${HDF5_VERSION}.tar.gz | \
        tar zx && \
    cd hdf5-${HDF5_VERSION} && \
    ./configure --enable-shared --prefix /usr/local/hdf5-${HDF5_VERSION} && \
    make -j2 && make install && \
    \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


USER $DOCKER_USER
ENV APlusPlus_VERSION=0.8.2

# Download and compile A++ and P++
RUN mkdir -p $DOCKER_HOME/overture && cd $DOCKER_HOME/overture && \
    curl -L http://overtureframework.org/software/AP-$APlusPlus_VERSION.tar.gz | \
        tar zx && \
    cd A++P++-$APlusPlus_VERSION && \
    ./configure --enable-SHARED_LIBS --prefix=`pwd` && \
    make -j2 && \
    make install && \
    make check && \
    \
    export MPI_ROOT=/usr/lib/x86_64-linux-gnu/openmpi && \
    ./configure --enable-PXX --prefix=`pwd` --enable-SHARED_LIBS \
       --with-mpi-include="-I${MPI_ROOT}/include" \
       --with-mpi-lib-dirs="-Wl,-rpath,${MPI_ROOT}/lib -L${MPI_ROOT}/lib" \
       --with-mpi-libs="-lmpi -lmpi_cxx" \
       --with-mpirun=/usr/bin/mpirun \
       --without-PADRE && \
    make -j2 && \
    make install && \
    make check

ENV APlusPlus=$DOCKER_HOME/overture/A++P++-$APlusPlus_VERSION/A++/install \
    PPlusPlus=$DOCKER_HOME/overture/A++P++-$APlusPlus_VERSION/P++/install \
    XLIBS=/usr/lib/X11 \
    OpenGL=/usr \
    MOTIF=/usr \
    HDF=/usr/local/hdf5-${HDF5_VERSION} \
    Overture=$DOCKER_HOME/overture/Overture.v26 \
    CG=$DOCKER_HOME/overture/cg.v26 \
    LAPACK=/usr/lib

WORKDIR $DOCKER_HOME/overture

# Download and compile Overture framework
# Note that the "distribution=ubuntu" command-line option breaks the
# configure script, so we need to hard-code it
RUN cd $DOCKER_HOME/overture && \
    git clone --depth 1 https://github.com/unifem/overture.git Overture.v26 && \
    \
    cd Overture.v26 && \
    sed -i -e 's/$distribution=""/$distribution="ubuntu"/g' ./configure && \
    ./configure opt --disable-X11 --disable-gl && \
    make -j2 && \
    make rapsodi && \
    ./check.p

# Download and compile CG without Maxwell equations
RUN cd $DOCKER_HOME/overture && \
    curl -L http://overtureframework.org/software/cg.v26.tar.gz | tar zx && \
    cd $CG && \
    make -j2 libCommon cgad cgcns cgins cgasf cgsm cgmp unitTests

USER

WORKDIR $DOCKER_HOME
USER root
