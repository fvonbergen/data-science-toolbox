# OS distribution detection.
OS_DISTRIBUTION := $(patsubst ID=%,%,$(shell cat /etc/os-release | grep "^ID="))
ifeq ($(OS_DISTRIBUTION),debian)
    PACKAGE_MANAGER := apt
    PACKAGE_INSTALL := $(PACKAGE_MANAGER) install -y
    DISTRIBUTION_PACKAGES := gettext-base ncurses-bin
else ifeq ($(OS_DISTRIBUTION),ubuntu)
    PACKAGE_MANAGER := apt
    PACKAGE_INSTALL := $(PACKAGE_MANAGER) install -y
    DISTRIBUTION_PACKAGES := gettext-base ncurses-bin
else ifeq ($(OS_DISTRIBUTION),alpine)
    PACKAGE_MANAGER := apk
    PACKAGE_INSTALL := $(PACKAGE_MANAGER) add
    DISTRIBUTION_PACKAGES := gettext ncurses
else
    $(error Unsupported OS distribution: $(OS_DISTRIBUTION))
endif

# Functions.
PRINT_MSG = $(shell . ./shell_functions.sh ; print_msg $(1) $(2))
DATE_TIME = $(shell date '+%Y-%m-%dT%H:%M:%S%Z')

# Variables.

# General variables.
TRUE := 1
FALSE := 0

# Project variables.
include config.mk
PROJECT_NAME ?= data-science-toolbox
DOCKER_PROJECT_NAME := $(PROJECT_NAME)
DOCKER_PROJECT_PATH ?= /$(PROJECT_NAME)
DOCKER_PROJECT_SERVICE := data-science-toolbox
DOCKER_PROJECT_IMAGE ?= $(PROJECT_NAME)
DOCKER_PROJECT_CONTAINER_NAME := $(PROJECT_NAME)
DOCKER_PROJECT_VOLUME_HOST_PATH ?= ./
DOCKER_PROJECT_VOLUME_CONTAINER_PATH ?= $(DOCKER_PROJECT_PATH)
JUPYTER_PORT ?= 8888
JUPYTER_NOTEBOOKS := notebooks
JUPYTER_NOTEBOOKS_DOCS := $(JUPYTER_NOTEBOOKS)/docs
PULL_IMAGE := $(if $(filter $(PULL_IMAGE),$(TRUE)),$(TRUE),$(FALSE))
# docker and docker-compose variables.
# docker env variables.
ENV_FILE_PREFIX := .env
DOCKER_ENV_FILE := $(ENV_FILE_PREFIX).build
DOCKER_ENV_IMAGE := $(DOCKER_PROJECT_IMAGE)
DOCKER_ENV_VOLUME_HOST_PATH := $(DOCKER_PROJECT_VOLUME_HOST_PATH)
DOCKER_ENV_VOLUME_CONTAINER_PATH := $(DOCKER_PROJECT_VOLUME_CONTAINER_PATH)
DOCKER_ENV_JUPYTER_PORT := $(JUPYTER_PORT)
DOCKER_ENVS := DOCKER_ENV_IMAGE=$(DOCKER_ENV_IMAGE) DOCKER_ENV_VOLUME_HOST_PATH=$(DOCKER_ENV_VOLUME_HOST_PATH) DOCKER_ENV_VOLUME_CONTAINER_PATH=$(DOCKER_ENV_VOLUME_CONTAINER_PATH) DOCKER_ENV_JUPYTER_PORT=$(DOCKER_ENV_JUPYTER_PORT)
BUILD_ENV_FILE = $(DOCKER_ENVS) bash -c "cat $(ENV_FILE_PREFIX).template | envsubst > $(DOCKER_ENV_FILE)"
# docker arg variables.
DOCKER_ARG_CONTAINER_PATH ?= $(DOCKER_PROJECT_PATH)
USER_ID := $(shell id -u)
DOCKER_ARG_USER_ID := $(if $(filter $(USER_ID),0),1000,$(USER_ID))
GROUP_ID := $(shell id -g)
DOCKER_ARG_GROUP_ID := $(if $(filter $(GROUP_ID),0),1000,$(GROUP_ID))
USER_NAME := $(shell whoami)
DOCKER_ARG_USER_NAME := $(if $(filter $(USER_NAME),root),user,$(USER_NAME))
DOCKER_BUILD_ARGS := --build-arg DOCKER_ARG_CONTAINER_PATH=$(DOCKER_ARG_CONTAINER_PATH) --build-arg DOCKER_ARG_USER_ID=$(DOCKER_ARG_USER_ID) --build-arg DOCKER_ARG_GROUP_ID=$(DOCKER_ARG_GROUP_ID) --build-arg DOCKER_ARG_USER_NAME=$(DOCKER_ARG_USER_NAME)
# docker variables
ENV_PARAM :=  --env-file $(DOCKER_ENV_FILE)
# docker-compose
DOCKER_COMPOSE = docker-compose --project-name $(DOCKER_PROJECT_NAME) 
NO_DEPS_FLAG := $(TRUE)
NO_DEPS_PARAMS = $(if $(filter $(NO_DEPS_FLAG),$(TRUE)),--no-deps --entrypoint="", $(if $(filter $(NO_DEPS_FLAG),$(FALSE)),,$(error "Invalid NO_DEPS_FLAG: $(NO_DEPS_FLAG)". Valid values are: [$(TRUE), $(FALSE)])))
DOCKER_COMPOSE_RUN_PARAMS = --name $(DOCKER_PROJECT_CONTAINER_NAME) --rm --service-ports $(NO_DEPS_PARAMS)
DOCKER_COMPOSE_RUN = $(DOCKER_COMPOSE) $(ENV_PARAM) run $(DOCKER_COMPOSE_RUN_PARAMS)
DOCKER_COMPOSE_BUILD := $(DOCKER_COMPOSE) $(ENV_PARAM) build --force-rm $(DOCKER_BUILD_ARGS) --quiet
DOCKER_COMPOSE_DOWN := $(DOCKER_COMPOSE) $(ENV_PARAM) down
# docker
DOCKER := docker
DOCKER_EXEC := $(DOCKER) exec

# Commands variables.
BLACK_COMMAND = black $(BLACK_PARAMS) $(JUPYTER_NOTEBOOKS)
UTILS_COMMANDS = $(BLACK_COMMAND)
PROJECT_COMMANDS = $(UTILS_COMMANDS)
JUPYTER_COMMAND = jupyter nbextensions_configurator enable --user && jupyter notebook --ip 0.0.0.0 --port $(JUPYTER_PORT) --no-browser $(JUPYTER_NOTEBOOKS)
JUPYTER_NOTEBOOKS_TO_PDF = jupyter nbconvert --to pdf $(JUPYTER_NOTEBOOKS)/$(NOTEBOOKS_FILES) --output-dir=$(JUPYTER_NOTEBOOKS_DOCS)

# Targets.
.PHONY: install build_image __docker_commands command jupyter notebooks_to_pdf check format clean

# install: Install project dependencies locally.
install:
	$(PACKAGE_INSTALL) bash docker-compose $(DISTRIBUTION_PACKAGES)

# build_image: builds the docker image.
build_image:
	@$(BUILD_ENV_FILE)
	@echo "$(call PRINT_MSG,"","-")"
	@echo "$(call PRINT_MSG,$(DATE_TIME),"-")"
	@echo "$(call PRINT_MSG,"","-")"
	@echo 'Building/Updating docker image. It may take some time...'
	@echo "$(call PRINT_MSG,"","-")"
	@if [ $(PULL_IMAGE) = $(TRUE) ]; then \
		# If pull fails try to run it with possibly old image. \
		$(DOCKER_COMPOSE_BUILD) --pull $(DOCKER_PROJECT_SERVICE) || $(DOCKER_COMPOSE_BUILD) $(DOCKER_PROJECT_SERVICE); \
	else \
		$(DOCKER_COMPOSE_BUILD) $(DOCKER_PROJECT_SERVICE); \
	fi


# __docker_compose_commands: internal target for starting and stopping docker-compose commands
__docker_compose_commands: build_image
	@echo "$(call PRINT_MSG,"","-")"
	@echo "$(call PRINT_MSG,$(DATE_TIME),"-")"
	@echo "$(call PRINT_MSG,"","-")"
	@echo 'Container command: $(DOCKER_COMMAND)'
	@echo "$(call PRINT_MSG,"","-")"
	@if $(DOCKER) ps --format "{{.Names}}" | grep -q $(DOCKER_PROJECT_CONTAINER_NAME); then \
		# TODO: docker-compose exec can't be used until this bug is fixed: https://github.com/docker/compose/pull/6647. docker-compose exec adds a <docker_container>_1 index that can't be omitted. \
		$(DOCKER_EXEC) -it $(DOCKER_PROJECT_CONTAINER_NAME) bash -c $(DOCKER_COMMAND); \
	else \
		$(DOCKER_COMPOSE_RUN) $(DOCKER_PROJECT_SERVICE) bash -c $(DOCKER_COMMAND); \
	fi
	@rm $(DOCKER_ENV_FILE)
	@echo "$(call PRINT_MSG,"","-")"

# The target should be called with a DOCKER_COMMAND="<command>" variable value.
# command target: runs the specified command inside the container.
command: __docker_compose_commands

# jupyter target: runs a jupyter notebook inside the container and exposes it to the host.
jupyter: DOCKER_COMMAND := "$(JUPYTER_COMMAND)"
jupyter: __docker_compose_commands

# Converts all the jupyter notebooks to pdf.
notebooks_to_pdf: NOTEBOOKS_FILES := *.ipynb
notebooks_to_pdf: DOCKER_COMMAND := "mkdir -p $(JUPYTER_NOTEBOOKS_DOCS);$(JUPYTER_NOTEBOOKS_TO_PDF)"
notebooks_to_pdf: __docker_compose_commands

# check: checks notebooks
check: BLACK_PARAMS := --check
check: DOCKER_COMMAND := "$(subst  ; , && ,$(UTILS_COMMANDS))"
check: __docker_compose_commands

# format: formats notebooks
format: DOCKER_COMMAND := "$(UTILS_COMMANDS)"
format: __docker_compose_commands

# down: bring docker-compose down --remove-orphans
down:
	@$(BUILD_ENV_FILE)
	$(DOCKER_COMPOSE_DOWN) --remove-orphans
	@rm -f $(DOCKER_ENV_FILE)

# clean: cleans project
clean: down
	@$(BUILD_ENV_FILE)
	$(DOCKER_COMPOSE_DOWN) -v --rmi all;$(DOCKER) image prune --force && $(DOCKER) volume prune --force
	@rm -f $(JUPYTER_NOTEBOOKS_DOCS)
	@rm -f $(DOCKER_ENV_FILE)
