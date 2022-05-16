FROM debian:bullseye-slim

# Update/Install packages.
RUN apt update && apt upgrade -y

# Install build framework debian packages dependencies.
# python
RUN apt install python3 python3-venv -y

# R
# Helpful: https://stackoverflow.com/questions/71242328/renv-venv-jupyterlab-irkernel-will-it-blenda
RUN apt install r-base-core -y
RUN Rscript -e "install.packages('renv')"

# Install nbconvert dependencies.
RUN apt install pandoc texlive-xetex texlive-fonts-recommended texlive-plain-generic -y

# Change working directory.
ARG DOCKER_ARG_CONTAINER_PATH
WORKDIR $DOCKER_ARG_CONTAINER_PATH

# Add non root user.
ARG DOCKER_ARG_USER_ID
ARG DOCKER_ARG_GROUP_ID
ARG DOCKER_ARG_USER_NAME

# Create user in Docker with host user parameters.
# Add group and user errors are ignored. Some Linux distribution don't need it ()
RUN addgroup --gid $DOCKER_ARG_GROUP_ID $DOCKER_ARG_USER_NAME || :
RUN adduser --disabled-password --gecos '' --uid $DOCKER_ARG_USER_ID --gid $DOCKER_ARG_GROUP_ID $DOCKER_ARG_USER_NAME || :

# virtualenv
# Add virtualenv directory environment variable. It will contain package dependencies.
ENV VIRTUAL_ENV /venv
# Create virtualenv directory.
RUN mkdir $VIRTUAL_ENV
# Copy package setup.cfg.
COPY setup.cfg $VIRTUAL_ENV
# Change virtualenv directory user access to host user
RUN chown -R  $DOCKER_ARG_USER_NAME:$DOCKER_ARG_USER_NAME $VIRTUAL_ENV

# renv
# Add renv directory environment variable. It will contain the renv folder and the renv files.
ENV R_ENV /renv
# Create renv directory.
RUN mkdir $R_ENV
# Copy package DESCRIPTION.
COPY DESCRIPTION $R_ENV
# Initialize renv.
RUN cd $R_ENV;Rscript -e "renv::init(bare=TRUE)"
# Change renv directory user access to host user
RUN chown -R  $DOCKER_ARG_USER_NAME:$DOCKER_ARG_USER_NAME $R_ENV

# Change root to host user.
USER $DOCKER_ARG_USER_NAME

# Necessary folder to run setup.py without errors
RUN mkdir $VIRTUAL_ENV/src
# Install project dependencies. Add paths to environment variables.
RUN python3 -m venv $VIRTUAL_ENV
RUN . $VIRTUAL_ENV/bin/activate && python -m pip install -q versioneer-518 wheel
RUN echo "from setuptools import setup;setup()" >> $VIRTUAL_ENV/setup.py
RUN sed -i 's/name = .*/name = TmpLibrary/' $VIRTUAL_ENV/setup.cfg
RUN . $VIRTUAL_ENV/bin/activate && python -m pip install -e $VIRTUAL_ENV
ENV PATH $VIRTUAL_ENV/bin:$PATH
ENV PYTHONPATH $VIRTUAL_ENV/bin
# Install R kernel.
RUN cd $R_ENV;Rscript -e "renv::install('IRkernel')"
RUN cd $R_ENV;Rscript -e "IRkernel::installspec()"
# Installs the project dependencies using the DESCRIPTION file.
RUN cd $R_ENV;Rscript -e "renv::install()"
# Install jupyter contrib extensions.
RUN jupyter contrib nbextension install --user
