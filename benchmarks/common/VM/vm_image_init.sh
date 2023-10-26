#!/usr/bin/bash

apt update

#Install gramine dependencies
apt install build-essential autoconf bison gawk nasm numactl -y
apt install ninja-build pkg-config python3 python3-click -y
apt install python3-jinja2 python3-pip python3-pyelftools wget -y
apt install meson python3-tomli python3-tomli-w -y
apt install libprotobuf-c-dev protobuf-c-compiler protobuf-compiler -y
apt install python3-cryptography python3-pip python3-protobuf -y

#Fetch the git URLs and the stable-commits
. /root/stable-commits

#Build and install gramine
cd /root
git clone ${GRAMINE_GIT_URL}
cd /root/gramine
git checkout ${GRAMINE_COMMIT}
meson setup build/ --buildtype=release -Ddirect=enabled -Dsgx=enabled
ninja -C build/
ninja -C build/ install

export PATH="/usr/local/bin/:$PATH" # to identify the gramine binaries
gramine-sgx-gen-private-key

#Get the Gramine examples
cd /root
git clone ${GRAMINE_EXAMPLES_GIT_URL}
cd /root/examples
git checkout ${GRAMINE_EXAMPLES_COMMIT}

#Setup the pytorch example
git apply /root/pytorch_benchmark.patch
apt install libnss-mdns libnss-myhostname -y
apt install python3-pip lsb-release -y
pip3 install torchvision pillow
cd /root/examples/pytorch
mkdir results
python3 download-pretrained-model.py
make SGX=1

# Apply the benchmark patches in the CI-Examples and build them (if needed)
# blender
apt install libxi6 libxxf86vm1 libxfixes3 libxrender1 -y
cd /root/gramine
git apply /root/blender_benchmark.patch
mkdir -p /root/gramine/CI-Examples/blender/results
cd /root/gramine/CI-Examples/blender
make
