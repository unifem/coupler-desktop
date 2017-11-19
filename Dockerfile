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

RUN pip3 install --no-cache-dir \
        https://bitbucket.org/dalcinl/igakit/get/default.tar.gz && \
    pip3 install --no-cache-dir \
        https://github.com/sfepy/sfepy/archive/release_${SFEPY_VERSION}.tar.gz

ADD image/home $DOCKER_HOME

########################################################
# Customization for user
########################################################

USER $DOCKER_USER
WORKDIR $DOCKER_HOME
USER root
