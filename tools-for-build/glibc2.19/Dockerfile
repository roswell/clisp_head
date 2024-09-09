FROM ubuntu:14.04
RUN apt-get update && apt-get install -y \
    build-essential git automake libcurl4-openssl-dev curl \
 && (apt-get install -y gcc-multilib lib32z1-dev || true ) \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
