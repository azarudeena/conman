#!/bin/bash

# I am assuming this is going to used in intel based Linux and Mac machines.
# This device a yq tool dependency if you are using other systems.
# please refer here  https://github.com/mikefarah/yq/releases


VERSION=4.11.2
OS="$(uname)"

if [[ "$OS" == "Linux" ]]; then
  BINARY=yq_linux_amd64
  wget https://github.com/mikefarah/yq/releases/download/v${VERSION}/${BINARY} -O /usr/bin/yq &&\
    chmod +x /usr/bin/yq
elif [[ "$OS" == "Darwin" ]]; then
  BINARY=yq_darwin_amd64
  wget https://github.com/mikefarah/yq/releases/download/v${VERSION}/${BINARY} -O /usr/bin/yq &&\
      chmod +x /usr/bin/yq
fi

