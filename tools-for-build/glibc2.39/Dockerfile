FROM ubuntu:24.04
RUN apt-get update && env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git automake libcurl4-openssl-dev curl \
 && (env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gcc-multilib lib32z1-dev || true )  \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
