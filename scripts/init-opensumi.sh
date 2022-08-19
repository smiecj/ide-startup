#!/bin/bash

# replace NB_PREFIX var (path url)
sed -i "s#NB_PREFIX#${NB_PREFIX}#g" /release/dist/bundle.js

sed -i "s#NB_PREFIX#${NB_PREFIX}#g" /release/dist-node/server/index.js

# copy extension
mkdir -p ${HOME}/.sumi
cp -r /extensions ${HOME}/.sumi
