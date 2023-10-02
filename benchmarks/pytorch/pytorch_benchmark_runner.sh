#!/usr/bin/bash

set -e

THIS_DIR=$(dirname "$(readlink -f "$0")")

# Run the experiments
vm_mem="16G" # VM memory
epc_mem="8G" # EPC memory for the VM (only used for sgx)
vm_types=("td" "efi" "sgx")
cpus=(1 2 4 6 8 12 16 20 24 32)

for vm in "${vm_types[@]}"; do
  for cpu in "${cpus[@]}"; do
    $THIS_DIR/pytorch_benchmark.expect $vm $cpu $vm_mem $epc_mem
  done
done