#!/bin/bash
sudo su
#mdadm --zero-superblock --force /dev/sd{a,b,c,d,e}
mdadm --create --verbose /dev/md0 -l 5 -n 5 /dev/sd{a,b,c,d,e}
mkdir /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
parted -s /dev/md0 mklabel gpt
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
mkdir -p /raid/part{1,2,3,4,5}
#хотя этот шаг можно пропустить
for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
#
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0" >> /etc/fstab ; done


