#!/bin/bash
set -e

# Set distro related parameters according to distro
DISTRO=$(grep -w 'NAME' /etc/os-release)
if [[ "$DISTRO" =~ .*"Ubuntu".* ]]; then
    QEMU_EXEC="/usr/bin/qemu-system-x86_64"
else
    QEMU_EXEC="/usr/libexec/qemu-kvm"
fi

GUEST_CID=18
MIGTD="/usr/share/td-migration/migtd.bin"
VIRTIO_SERIAL=false
MIGTD_TYPE=""
DEST_IP="127.0.0.1"

usage() {
    cat << EOM
Usage: $(basename "$0") [OPTION]...
  -m <migtd file>           MigTD file
  -t <src|dst>              Must set migtd type, src or dst
  -h                        Show this help
EOM
}

process_args() {
    while getopts "i:m:t:hs" option; do
        case "${option}" in
            i) DEST_IP=$OPTARG;;
            m) MIGTD=$OPTARG;;
            t) MIGTD_TYPE=$OPTARG;;
            s) VIRTIO_SERIAL=true;;
            h) usage
               exit 0
               ;;
            *)
               echo "Invalid option '-$OPTARG'"
               usage
               exit 1
               ;;
        esac
    done

    if [[ -z ${MIGTD_TYPE} ]]; then
        usage
        error "Must set MIGTD_TYPE -t [src|dst]"
    fi

    if [[ ${VIRTIO_SERIAL} == true ]]; then
        MIGTD="/usr/share/td-migration/migtd-serial.bin"
    fi

    case ${MIGTD_TYPE} in
        "src")
            GUEST_CID=18
            ;;
        "dst")
            GUEST_CID=36
            ;;
        *)
            error "Invalid ${MIGTD_TYPE}, must be [src|dst]"
            ;;
    esac
}

error() {
    echo -e "\e[1;31mERROR: $*\e[0;0m"
    exit 1
}

launch_migTD() {
QEMU_CMD="${QEMU_EXEC} \
-accel kvm \
-M q35 \
-cpu host,host-phys-bits,-kvm-steal-time,pmu=off \
-smp 1,threads=1,sockets=1 \
-m 1G \
-object tdx-guest,id=tdx0,sept-ve-disable=off,debug=off,quote-generation-service=vsock:1:4050 \
-object memory-backend-memfd-private,id=ram1,size=1G \
-machine q35,memory-backend=ram1,confidential-guest-support=tdx0,kernel_irqchip=split \
-bios ${MIGTD} \
-name migtd-${MIGTD_TYPE},process=migtd-${MIGTD_TYPE},debug-threads=on \
-no-hpet \
-nographic -vga none -nic none \
-serial mon:stdio \
-pidfile /var/run/migtd-${MIGTD_TYPE}.pid"

    if [[ ${VIRTIO_SERIAL} == true ]]; then
        QEMU_CMD+=" -device virtio-serial-pci,id=virtio-serial0 "
        if [[ ${MIGTD_TYPE} == "src" ]]; then
            QEMU_CMD+=" -chardev socket,host=0.0.0.0,port=1236,server=on,id=foo "
        else
            QEMU_CMD+=" -chardev socket,host=${DEST_IP},port=1236,server=off,id=foo "
        fi
        QEMU_CMD+=" -device virtserialport,chardev=foo,bus=virtio-serial0.0 "
    else
        QEMU_CMD+=" -device vhost-vsock-pci,id=vhost-vsock-pci1,guest-cid=${GUEST_CID},disable-legacy=on "
    fi

    eval "${QEMU_CMD}"
}

process_args "$@"
launch_migTD
