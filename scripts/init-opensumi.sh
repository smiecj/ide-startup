#!/bin/bash

sed -i "s#NB_PREFIX#${NB_PREFIX}#g" /release/dist/bundle.js

sed -i "s#NB_PREFIX#${NB_PREFIX}#g" /release/dist-node/server/index.js