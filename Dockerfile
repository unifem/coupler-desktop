# Builds a Docker image with Ubuntu 16.04, FEniCS, Python3 and Jupyter Notebook
# for "AMS 529: Finite Element Methods" at Stony Brook University
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

FROM compdatasci/octave-desktop:latest
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

# Install system packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        gdb \
        ccache \
        libnss3 \
        \
        liblapack-dev \
        libopenblas-dev \
        libomp-dev \
        \
        meld && \
    apt-get clean && \
    pip3 install -U \
        numpy \
        scipy \
        sympy \
        pandas \
        matplotlib \
        autopep8 \
        flake8 \
        PyQt5 \
        spyder && \
    ln -s -f /usr/local/bin/spyder3 /usr/local/bin/spyder && \
    rm -rf /var/lib/apt/lists/* /tmp/*

########################################################
# Customization for user
########################################################

ADD image/etc /etc
ADD image/bin /usr/local/bin
ADD image/home $DOCKER_HOME

USER $DOCKER_USER
ENV  GIT_EDITOR=vi EDITOR=vi
RUN echo 'export OMP_NUM_THREADS=$(nproc)' >> $DOCKER_HOME/.profile && \
    sed -i '/octave/ d' $DOCKER_HOME/.config/lxsession/LXDE/autostart && \
    echo "PATH=$DOCKER_HOME/bin:$PATH" >> $DOCKER_HOME/.profile

WORKDIR $DOCKER_HOME
USER root
