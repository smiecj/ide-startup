FROM node:14 as builder

# 用户工作空间，用于打包到前端工作空间地址
ENV WORKSPACE_DIR workspace
ENV EXTENSION_DIR extensions

ARG code_home=/opt/coding
ARG startup_home=${code_home}/ide-startup
ARG core_home=${code_home}/opensumi-core
RUN mkdir -p ${code_home}
RUN cd ${code_home} && git clone https://github.com/smiecj/ide-startup -b dev_1_16

ENV ELECTRON_MIRROR http://npm.taobao.org/mirrors/electron/

RUN mkdir -p ${WORKSPACE_DIR}  &&\
    mkdir -p ${EXTENSION_DIR}

ARG registry="https://registry.npm.taobao.org"
RUN echo "registry = $registry" >> $HOME/.npmrc

RUN cd ${startup_home} && yarn --ignore-scripts --network-timeout 1000000 && \
    # websocket path
    sed -i "s#'/service'#process.env.NB_PREFIX != '' ? process.env.NB_PREFIX : '/service'#g" node_modules/@opensumi/ide-core-node/lib/connection.js && \
    yarn run build && \
    yarn run download:extensions && \
    rm -rf ./node_modules

FROM node:14 as app

ENV WORKSPACE_DIR /workspace
ENV EXTENSION_DIR /root/.sumi/extensions
ENV EXT_MODE js
ENV NODE_ENV production

RUN mkdir -p ${WORKSPACE_DIR}  &&\
    mkdir -p ${EXTENSION_DIR}

ENV NB_USER jovyan
ENV NB_UID 1000
ENV HOME /home/$NB_USER

# https://github.com/nodejs/docker-node/issues/289#issuecomment-267081557
RUN groupmod -g 1001 node \
  && usermod -u 1001 -g 1001 node

RUN useradd -M -s /bin/bash -N -u ${NB_UID} ${NB_USER} \
 && mkdir -p ${HOME} \
 && chown -R ${NB_USER}:users ${HOME} \
 && chown -R ${NB_USER}:users /usr/local/bin

WORKDIR /release

COPY ./configs/docker/productionDependencies.json package.json

RUN yarn --network-timeout 1000000

ARG code_home=/opt/coding
ARG startup_home=${code_home}/ide-startup

COPY --from=builder ${startup_home}/dist dist
COPY --from=builder ${startup_home}/dist-node dist-node
COPY --from=builder ${startup_home}/hosted hosted
COPY --from=builder ${startup_home}/extensions /root/.sumi/extensions
RUN ls -l /release

EXPOSE 8888
ENV IDE_SERVER_PORT 8888

RUN chown -R ${NB_USER}:users /release

# 后续: 完善镜像，提供基本指令和 python 环境
# RUN apt update && apt -yq install --no-install-recommends \
#     apt-transport-https \
#     bash \
#     bzip2 \
#     ca-certificates \
#     curl \
#     git \
#     gnupg \
#     gnupg2 \
#     locales \
#     lsb-release \
#     nano \
#     software-properties-common \
#     tzdata \
#     unzip \
#     vim \
#     wget \
#     zip

USER ${NB_UID}

CMD [ "node", "/release/dist-node/server/index.js" ]
