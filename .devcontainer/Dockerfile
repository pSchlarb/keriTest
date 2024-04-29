FROM mcr.microsoft.com/devcontainers/python:1-3.12-bullseye

RUN apt update && apt install -y libsodium-dev rustc cargo git

WORKDIR /workspaces

RUN git clone https://github.com/WebOfTrust/keripy.git && cd keripy && git checkout 1.2.0-dev2 && sudo pip install ./ && cd ..
RUN git clone https://github.com/WebOfTrust/vLEI.git && cd vLEI && pip install ./