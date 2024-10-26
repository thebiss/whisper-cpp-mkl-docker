
#
# docker build -t bbissell/llama-cpp-mkl:b3467
#

ARG  ONEAPI_IMAGE_VER=2024.2.1-0-devel-ubuntu22.04

##
## Build Stage
##
FROM intel/oneapi-basekit:${ONEAPI_IMAGE_VER} AS build

RUN useradd -m --uid 1020 whisperuser
USER 1010:1010
WORKDIR /home/whisperuser

ARG WHISPERCPP_VERSION_TAG=b3467
ENV WHISPERCPP_VERSION=${WHISPERCPP_VERSION_TAG}

# Fetch from repo
ADD --chown=1010:1010 --keep-git-dir=true https://github.com/ggerganov/llama.cpp.git#${WHISPERCPP_VERSION_TAG} git
WORKDIR git

# You can skip this step if  in oneapi-basekit docker image, only required for manual installation
# source /opt/intel/oneapi/setvars.sh 
RUN cmake -B build -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=Intel10_64lp -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DGGML_NATIVE=ON

# make only the server target
RUN cmake --build build --config Release --target llama-server

# cleanup ahead of the runtime copy
RUN find ./ \( -name '*.o' -o -name '*.cpp' -o -name '*.c' -o -name '*.cu?' -o -name '*.hpp' -o -name '*.h' -o -name '*.comp' \) -print -delete

##
## Runtime
##
FROM intel/oneapi-runtime:${ONEAPI_IMAGE_VER} AS runtime

RUN useradd -m --uid 1020 whisperuser
USER 1020:1020
WORKDIR /home/whisperuser

COPY --from=build /home/whisperuser/git ./git

COPY lf.sh .
ENV LLAMA_SERVER_BIN=/home/whisperuser/git/build/bin/llama-server

## Run phase

# mount models externally
VOLUME [ "/var/models" ]
EXPOSE 8080

# lf gets the bin name from LLAMA_SERVER_BIN
CMD /home/whisperuser/lf.sh
