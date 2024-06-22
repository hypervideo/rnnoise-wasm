FROM emscripten/emsdk:3.1.61

RUN apt-get update && \
    apt-get install -y libtool autotools-dev autoconf automake
