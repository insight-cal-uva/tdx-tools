#!/usr/bin/bash

set -e

THIS_DIR=$(dirname "$(readlink -f "$0")")
MOUNTPOINT=$THIS_DIR/tmp_mnt
RESULTS_DIR=$THIS_DIR/results

# Gather the results from the guest image
mkdir -p $MOUNTPOINT
sudo guestmount -a $THIS_DIR/../common/VM/td-guest-ubuntu-22.04.qcow2 -i --ro $MOUNTPOINT

mkdir -p $RESULTS_DIR
sudo bash -c "cp -r $MOUNTPOINT/root/gramine/CI-Examples/sqlite-tmpfs/results/* $RESULTS_DIR"

sudo umount $MOUNTPOINT
rm -rf $MOUNTPOINT

# Pretty print the results
declare -A data

max_vm_type_length=0

for file in $RESULTS_DIR/*.txt; do
  file_name=$(basename "$file")
  operation=$(echo "$file_name" | cut -d'_' -f1)
  vm_type=$(echo "$file_name" | cut -d'_' -f2)
  thread=$(echo "$file_name" | cut -d'_' -f3)
  # get the elapsed time
  time_taken=$(cat "$file" | grep "elapsed time" | sed -E 's,^[^0-9]*([0-9]+.[0-9]+).*$,\1,') 
  data["$operation,$vm_type,$thread"]=$time_taken

  if [[ ${#vm_type} -gt max_vm_type_length ]]; then
    max_vm_type_length=${#vm_type}
  fi
done

operations=$(echo "${!data[@]}" | tr ' ' '\n' | cut -d',' -f1 | sort -u)
vm_types=$(echo "${!data[@]}" | tr ' ' '\n' | cut -d',' -f2 | sort -u)
thread_nums=$(echo "${!data[@]}" | tr ' ' '\n' | cut -d',' -f3 | sort -n -u)

for operation in $operations; do
  printf "$operation\n"
  header="VM Type\Threads"
  if [[ ${#header} -gt max_vm_type_length ]]; then
    max_vm_type_length=${#header}
  fi

  printf "%-${max_vm_type_length}s\t" "VM Type\Threads"
  for thread in $thread_nums; do
    printf "%s\t" "$thread"
  done
  printf "\n"

  for vm_type in $vm_types; do
    printf "%-${max_vm_type_length}s\t" "$vm_type"
    for thread in $thread_nums; do
      key="$operation,$vm_type,$thread"
      if [ -n "${data[$key]}" ]; then
        printf "%s\t" "${data[$key]}"
      else
        printf "N/A\t"
      fi
    done
    printf "\n"
  done
  printf "\n"
done
