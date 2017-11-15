# Builds a Docker image with Ubuntu 16.04, Python 3, Jupyter Notebook,
# CGNS/pyCGNS, MOAB/pyMOAB, and DataTransferKit for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use fenics-desktop as base image
FROM unifem/fenics-desktop
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

# Install system packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        automake autogen autoconf libtool \
        libhdf5-mpich-dev \
        libnetcdf-dev netcdf-bin \
        libmetis5 libmetis-dev \
        \
        tk-dev \
        libglu1-mesa-dev \
        libxmu-dev && \
    apt-get clean && \
    pip3 install -U \
        cython \
        nose && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Install CGNS
RUN cd /tmp && \
    mkdir /usr/lib/hdf5 && \
    ln -s -f /usr/include/hdf5/mpich /usr/lib/hdf5/include && \
    ln -s -f /usr/lib/x86_64-linux-gnu/hdf5/mpich /usr/lib/hdf5/lib  && \
    git clone --depth=1 -b master https://github.com/CGNS/CGNS.git && \
    cd CGNS/src && \
    export CC="mpicc.mpich" && \
    export LIBS="-Wl,--no-as-needed -ldl -lz -lsz -lpthread" && \
    ./configure --enable-64bit --with-zlib --with-hdf5=/usr/lib/hdf5 \
        --enable-cgnstools --enable-lfs --enable-shared && \
    sed -i 's/TKINCS =/TKINCS = -I\/usr\/include\/tcl/' cgnstools/make.defs && \
    make -j2 && make install && \
    rm -rf /tmp/CGNS

# Install pyCGNS
RUN cd /tmp && \
    git clone --depth=1 -b master https://github.com/unifem/pyCGNS.git && \
    cd pyCGNS && \
    python3 setup.py build \
        --includes=/usr/include/hdf5/mpich:/usr/include/mpich \
        --libraries=/usr/lib/x86_64-linux-gnu/hdf5/mpich && \
    python3 setup.py install && \
    rm -rf /tmp/pyCGNS

# Install MOAB and pymoab
RUN cd /tmp && \
    git clone --depth=1 https://bitbucket.org/fathomteam/moab.git && \
    cd moab && \
    autoreconf -fi && \
    ./configure \
        --prefix=/usr/local \
        --with-mpi=/usr/lib/mpich \
        CC=mpicc.mpich \
        CXX=mpicxx.mpich \
        FC=mpif90.mpich \
        F77=mpif77.mpich \
        --enable-optimize \
        --enable-shared=yes \
        --with-blas=-lopenblas \
        --with-lapack=-lopenblas \
        --with-scotch=$PETSC_DIR \
        --with-metis=/usr/lib/x86_64-linux-gnu \
        --with-eigen3=/usr/include/eigen3 \
        --with-x \
        --with-cgns \
        --with-netcdf \
        --with-hdf5=/usr/lib/hdf5 \
        --with-hdf5-ldflags="-L/usr/lib/hdf5/lib" \
        --enable-ahf=yes \
        --enable-tools=yes && \
    make -j2 && make install && \
    \
    cd pymoab && \
    python3 setup.py install && \
    rm -rf /tmp/moab

# Install DDataTransferKit
RUN cd /tmp && \
    git clone --depth 1 --branch trilinos-release-12-12-1 \
        https://github.com/trilinos/Trilinos.git && \
    cd Trilinos && \
    git clone --depth 1 --branch dtk-2.0 \
        https://github.com/ORNL-CEES/DataTransferKit.git && \
    mkdir build && cd build && \
    cmake \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr/local \
        -DCMAKE_BUILD_TYPE:STRING=DEBUG \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=OFF \
        -DCMAKE_SHARED_LIBS:BOOL=ON \
        -DTPL_ENABLE_MPI:BOOL=ON \
        -DTPL_ENABLE_Boost:BOOL=ON \
        -DBoost_INCLUDE_DIRS:PATH=/usr/include/boost \
        -DTPL_ENABLE_Libmesh:BOOL=OFF \
        -DTPL_ENABLE_MOAB:BOOL=ON \
        -DMOAB_INCLUDE_DIRS=/usr/local/include \
        -DMOAB_LIBRARY_DIRS=/usr/local/lib \
        -DTPL_ENABLE_Netcdf:BOOL=ON \
        -DTPL_ENABLE_BinUtils:BOOL=OFF \
        -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES:BOOL=OFF \
        -DTrilinos_ENABLE_ALL_PACKAGES=OFF \
        -DTrilinos_EXTRA_REPOSITORIES="DataTransferKit" \
        -DTrilinos_ENABLE_EXPLICIT_INSTANTIATION:BOOL=ON \
        -DTrilinos_ASSERT_MISSING_PACKAGES:BOOL=OFF \
        -DTrilinos_ENABLE_TESTS:BOOL=OFF \
        -DTrilinos_ENABLE_EXAMPLES:BOOL=OFF \
        -DTrilinos_ENABLE_CXX11:BOOL=ON \
        -DTrilinos_ENABLE_Tpetra:BOOL=ON \
        -DTpetra_INST_INT_UNSIGNED_LONG:BOOL=ON \
        -DTPL_ENABLE_BLAS:BOOL=ON \
        -DTPL_BLAS_LIBRARIES=/usr/lib/libopenblas.so \
        -DTPL_ENABLE_LAPACK:BOOL=ON \
        -DTPL_LAPACK_LIBRARIES=/usr/lib/libopenblas.so \
        -DTPL_ENABLE_Eigen:BOOL=ON \
        -DTPL_Eigen_INCLUDE_DIRS=/usr/include/eigen3 \
        -DTrilinos_ENABLE_DataTransferKit=ON \
        -DDataTransferKit_ENABLE_DBC=ON \
        -DDataTransferKit_ENABLE_TESTS=ON \
        -DDataTransferKit_ENABLE_EXAMPLES=OFF \
        -DDataTransferKit_ENABLE_ClangFormat=OFF \
        -DTPL_ENABLE_BoostLib:BOOL=OFF \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        .. && \
    make -j2 && \
    make install && \
    \
    rm -rf /tmp/Trilinos

ADD image/home $DOCKER_HOME

########################################################
# Customization for user
########################################################

USER $DOCKER_USER
WORKDIR $DOCKER_HOME
USER root
