FROM ubuntu:20.04
RUN apt-get update && env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git automake libcurl4-openssl-dev curl \
    dh-autoreconf bash-completion \
 && (env DEBIAN_FRONTEND=noninteractive apt-get install -y gcc-multilib || true) \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
