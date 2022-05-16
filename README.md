# Data Science Toolbox

Project that allows to start a jupyter notebook server with python and R languages configured in a docker environment.

## Installation

### GNU/Linux based OS installation

#### Alpine

Run in terminal:

```shell
sudo apk add make
sudo make install
```

#### Debian

Run in terminal:

```shell
sudo apt install make -y
sudo make install
```

#### Ubuntu

Run in terminal:

```shell
sudo apt install make -y
sudo make install
```

## Usage

Docker image is built and the jupyter notebook server is started uby executing:

```shell
make jupyter
```

Image built or update takes a lot of time. Many things need to be installed and configured. To quit at any point or to shutdown the jupyter notebook server press CTRL+C.

python dependencies are installed from the file `setup.cfg`. R dependencies are installed from the file `DESCRIPTION`. `config.mk` contains variables that configure the jupyter execution.

To bring the docker container down, execute:

```shell
make down
```

python jupyter notebooks can be formatted by running:

```shell
make format
```

For converting all jupyter notebooks to pdf:
```shell
make notebooks_to_pdf
```

A command in the docker container can be executed with:
```shell
make command DOCKER_COMMAND="<command>"
```

To clean docker resources run:

```shell
make clean
```

Be aware that running this command will erase the docker image.
