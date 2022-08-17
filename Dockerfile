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

RUN echo "198.41.30.195 open-vsx.org" >> /etc/hosts

RUN cd ${startup_home} && yarn --ignore-scripts --network-timeout 1000000 && \
    sed -i "s#opts.pathPrefix.length);#opts.pathPrefix.length);\n          if (! ctx.path){\n            ctx.path = \"/\";\n          } #g" node_modules/koa-static-prefix/index.js && \
    sed -i "s#'/service'#'NB_PREFIX/service'#g" node_modules/@opensumi/ide-core-node/lib/connection.js && \
    yarn run build && \
    yarn run download:extensions && \
    rm -rf ./node_modules

FROM node:14 as app

ENV WORKSPACE_DIR /workspace
ENV EXT_MODE js
ENV NODE_ENV production

ENV NB_USER jovyan
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV EXTENSION_DIR $HOME/.sumi/extensions

RUN mkdir -p ${WORKSPACE_DIR}  &&\
    mkdir -p ${EXTENSION_DIR}

# https://github.com/nodejs/docker-node/issues/289#issuecomment-267081557
RUN groupmod -g 1001 node \
  && usermod -u 1001 -g 1001 node

RUN useradd -M -s /bin/bash -N -u ${NB_UID} ${NB_USER} \
 && mkdir -p ${HOME} \
 && chown -R ${NB_USER}:users ${HOME} \
 && chown -R ${NB_USER}:users /usr/local/bin \
 && chown -R ${NB_USER}:users ${WORKSPACE_DIR} \
 && chown -R ${NB_USER}:users ${EXTENSION_DIR}

WORKDIR /release

COPY ./configs/docker/productionDependencies.json package.json

RUN yarn --network-timeout 1000000

ARG code_home=/opt/coding
ARG startup_home=${code_home}/ide-startup

COPY --from=builder ${startup_home}/dist dist
COPY --from=builder ${startup_home}/dist-node dist-node
COPY --from=builder ${startup_home}/hosted hosted
COPY --from=builder ${startup_home}/extensions ${EXTENSION_DIR}
COPY ./scripts/init-opensumi.sh /release/
# init script

RUN ls -l /release

EXPOSE 8888
ENV IDE_SERVER_PORT 8888

RUN chown -R ${NB_USER}:users /release

# install basic command
ARG apt_key="871920D1991BC93C"
COPY sources.list /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ${apt_key}
RUN apt update && apt -yq install --no-install-recommends \
    apt-transport-https \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    git \
    gnupg \
    gnupg2 \
    locales \
    lsb-release \
    nano \
    unzip \
    vim \
    wget \
    zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# install python (conda)
ENV CONDA_DIR /opt/conda
ENV PATH "${CONDA_DIR}/bin:${PATH}"
RUN mkdir -p ${CONDA_DIR} \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> ${HOME}/.bashrc \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> /etc/profile \
 && echo "conda activate base" >> ${HOME}/.bashrc \
 && echo "conda activate base" >> /etc/profile \
 && chown -R ${NB_USER}:users ${CONDA_DIR} \
 && chown -R ${NB_USER}:users ${HOME}

ARG PIP_VERSION=21.1.2
ARG PYTHON_VERSION=3.8.10
ARG CONDA_REPO_HOME=https://mirrors.tuna.tsinghua.edu.cn/github-release/conda-forge/miniforge
ARG TARGETARCH
SHELL ["/bin/bash", "-c"]
RUN conda_version=`curl -L ${CONDA_REPO_HOME} | grep "title=" | grep -v "LatestRelease" | sed 's/.*title="//g' | sed 's/".*//g'` && \
    if [[ "arm64" == "${TARGETARCH}" ]]; \
    then\
        arch="aarch64";\
    else\
        arch="x86_64";\
    fi && \
    conda_download_url=${CONDA_REPO_HOME}/${conda_version}/Miniforge3-${conda_version}-Linux-${arch}.sh && \
    curl -sL ${conda_download_url} -o /tmp/Miniforge3.sh && \
    /bin/bash /tmp/Miniforge3.sh -b -f -p ${CONDA_DIR} \
    && rm /tmp/Miniforge3.sh \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && echo "conda ${conda_version:0:-2}" >> ${CONDA_DIR}/conda-meta/pinned \
    && echo "python ${PYTHON_VERSION}" >> ${CONDA_DIR}/conda-meta/pinned \
    && conda install -y -q \
        python=${PYTHON_VERSION} \
        conda=${conda_version:0:-2} \
        pip=${PIP_VERSION} \
    && conda update -y -q --all \
    && conda clean -a -f -y \
    && chown -R ${NB_USER}:users ${CONDA_DIR} \
    && chown -R ${NB_USER}:users ${HOME}

USER ${NB_UID}

# install requirement
COPY --chown=jovyan:users requirements.txt /tmp
RUN python3 -m pip install -r /tmp/requirements.txt --quiet --no-cache-dir \
 && rm -f /tmp/requirements.txt

# alias

RUN sed -i "s/alias cp/#alias cp/g" $HOME/.bashrc
RUN sed -i "s/alias mv/#alias mv/g" $HOME/.bashrc
RUN echo "alias ll='ls -l'" >> $HOME/.bashrc
RUN echo "alias rm='rm -f'" >> $HOME/.bashrc

CMD sh /release/init-opensumi.sh && node /release/dist-node/server/index.js
