#######################################
## This Dockerfile requires BuildKit ##
#######################################

## General arguments
ARG REGISTRY=jfrog.vpayusa.net/plinfharbor
ARG DOTNET_VERSION=6.0
ARG DOTNET_SDK_VARIANT=commit-master
ARG DOTNET_RUNTIME_VARIANT=commit-master
ARG BASE_SDK_IMAGE=dotnet-bogner-sdk
ARG BASE_RUNTIME_IMAGE=dotnet-bogner-aspnetcore

## Build Stage
FROM ${REGISTRY}/base-images/${BASE_SDK_IMAGE}-${DOTNET_VERSION}:${DOTNET_SDK_VARIANT} as build

## Build stage arguments
ARG CONFIG_PROFILE=Release
ARG PROJECT_DIR
ARG PROJECT_NAME

ENV PROJECT=${PROJECT_DIR}/${PROJECT_NAME}.csproj
WORKDIR /app

COPY nuget.config* ./
COPY *.sln ./

## Copy .csproj files into the correct file structure
SHELL ["/bin/bash", "-O", "globstar", "-c"]
RUN --mount=target=docker_build_context \
cd docker_build_context;\
cp **/*.csproj ../ --parents;
RUN rm -rf docker_build_context
SHELL ["/bin/sh", "-c"]

## Restore project
RUN dotnet restore ${PROJECT}
## Copy all files if restore succeeds
COPY . ./
## Publish project without restoring
RUN dotnet publish --no-restore -c ${CONFIG_PROFILE} -o /app/out ${PROJECT}

## New stage used to reduce the size of the final image
FROM $REGISTRY/base-images/${BASE_RUNTIME_IMAGE}-${DOTNET_VERSION}:${DOTNET_RUNTIME_VARIANT} AS final
## Final stage arguments
ARG PROJECT_NAME

COPY --chown=bogner:bogner src/requirements_py3.txt /
COPY --chown=bogner:bogner lib/*.deb .

# TODO: split into Dockerfile.bogner.python
RUN apt-get update \
    && ACCEPT_EULA=y apt-get install -y --no-install-recommends \
        default-jre-headless \
        "g++" \
        jq \
        libbcprov-java \
        libcommons-lang3-java \
        libmysqlclient-dev \
        msodbcsql18 \
        python3-dev \
        python3-pip \
    && dpkg -i ./*.deb \
    && python3 -m pip install --upgrade \
        pip \
        "setuptools<58" \
        wheel \
    && python3 -m pip install --upgrade -r /requirements_py3.txt \
    && rm -rf /var/cache/apk/* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f ./*.deb

WORKDIR /app

COPY --from=build --chown=bogner:bogner /app/out .
ENV ASPNETCORE_URLS=http://+:8080

## Create a symlink so we can use exec form entrypoint
RUN ln -s ${PROJECT_NAME}.dll Entrypoint.dll

# Changing user after creating symbolic link to ensure user has permission to create that link
USER bogner:bogner

ENTRYPOINT [ "dotnet", "Entrypoint.dll" ]

## Optionally add image build time
ARG IMAGE_BUILD_TIME
ENV IMAGE_BUILD_TIME ${IMAGE_BUILD_TIME}
