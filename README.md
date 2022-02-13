## Домашнее задание - дисковая подсистема
## 1. Добавляем 5й диск в Vagrant файл
```
                MACHINES = {
  :otuslinux => {
        :box_name => "centos/7",
        :ip_addr => '192.168.11.101',
        :disks => {
                :sata1 => {
                        :dfile => './sata1.vdi',
                        :size => 250,
                        :port => 1
                },
                :sata2 => {
                        :dfile => './sata2.vdi',
                        :size => 250, # Megabytes
                        :port => 2
                },
                :sata3 => {
                        :dfile => './sata3.vdi',
                        :size => 250,
                        :port => 3
                },
                :sata4 => {
                        :dfile => './sata4.vdi',
                        :size => 250, # Megabytes
                        :port => 4
                },
                :sata5 => {
                        :dfile => './sata5.vdi',
                        :size => 250, # Megabytes
                        :port => 5
                }
        }
  },
}
```

## 2. Работаем внутри образа
Запустим образ и зайдем в него
```bash
vagrant up
vagrant ssh
```
Посмотрим блочные устройства
```bash
[vagrant@otuslinux ~]$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0  250M  0 disk
sdb      8:16   0  250M  0 disk
sdc      8:32   0  250M  0 disk
sdd      8:48   0  250M  0 disk
sde      8:64   0  250M  0 disk
sdf      8:80   0   40G  0 disk
└─sdf1   8:81   0   40G  0 part /
```
Наши 5 дисков для создания рейда sd{a,b,c,d,e}. sdf - используется и размечан, его не трогать не будем.

По методичке:
```bash
mdadm --zero-superblock --force /dev/sd{a,b,c,d,e}
```
дает результат:
```
mdadm: Unrecognised md component device - /dev/sda
mdadm: Unrecognised md component device - /dev/sdb
mdadm: Unrecognised md component device - /dev/sdc
mdadm: Unrecognised md component device - /dev/sdd
mdadm: Unrecognised md component device - /dev/sde
```
Что вполне себе естественно, ведь суперблока у нас еще нет. Диски чистые без разделдов, без файловой системы - соответственно суперблока на них еще нет.

Создаем рейд:
```bash
[vagrant@otuslinux ~]$ sudo mdadm --create --verbose /dev/md0 -l 5 -n 5 /dev/sd{a,b,c,d,e}
mdadm: layout defaults to left-symmetric
mdadm: layout defaults to left-symmetric
mdadm: chunk size defaults to 512K
mdadm: size set to 253952K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```
Ну, и по условию задачи, создать рейд 0/1/5/10 - поэтому меняем параметр -l на 5 для создания RAID-5 рейда.

Проверим что RAID собралсā нормально:
```bash
[vagrant@otuslinux ~]$ cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4]
md0 : active raid5 sde[5] sdd[3] sdc[2] sdb[1] sda[0]
      1015808 blocks super 1.2 level 5, 512k chunk, algorithm 2 [5/5] [UUUUU]

unused devices: <none>
```

Создадим каталог для файлов конфигураций mdadm и файл конфига
```
sudo mkdir /etc/mdadm
sudo su #Надоел sudo
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```

Сломаем и починим:
```bash
[root@otuslinux vagrant]# mdadm /dev/md0 --fail /dev/sde
mdadm: set /dev/sde faulty in /dev/md0
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4]
md0 : active raid5 sde[5](F) sdd[3] sdc[2] sdb[1] sda[0]
      1015808 blocks super 1.2 level 5, 512k chunk, algorithm 2 [5/4] [UUUU_]

unused devices: <none>
```
видим, что 5й диск "вышел из строя"
более точная информация
```bash
[root@otuslinux vagrant]# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Sun Feb 13 10:00:34 2022
        Raid Level : raid5
        Array Size : 1015808 (992.00 MiB 1040.19 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Feb 13 10:56:18 2022
             State : clean, degraded
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 1
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 5d1f8b4c:a709771a:c3fc996b:d4105f67
            Events : 20

    Number   Major   Minor   RaidDevice State
       0       8        0        0      active sync   /dev/sda
       1       8       16        1      active sync   /dev/sdb
       2       8       32        2      active sync   /dev/sdc
       3       8       48        3      active sync   /dev/sdd
       -       0        0        4      removed

       5       8       64        -      faulty   /dev/sde
```
Удалим сломанный диск из массива
```bash
[root@otuslinux vagrant]# mdadm /dev/md0 --remove /dev/sde
mdadm: hot removed /dev/sde from /dev/md0
```
Заменили диск и вернем его в работу, и убедимся, что все починилось
```bash
[root@otuslinux vagrant]# mdadm /dev/md0 --add /dev/sde
mdadm: added /dev/sde
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4]
md0 : active raid5 sde[5] sdd[3] sdc[2] sdb[1] sda[0]
      1015808 blocks super 1.2 level 5, 512k chunk, algorithm 2 [5/5] [UUUUU]

unused devices: <none>
[root@otuslinux vagrant]# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Sun Feb 13 10:00:34 2022
        Raid Level : raid5
        Array Size : 1015808 (992.00 MiB 1040.19 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Feb 13 11:10:35 2022
             State : clean
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 5d1f8b4c:a709771a:c3fc996b:d4105f67
            Events : 40

    Number   Major   Minor   RaidDevice State
       0       8        0        0      active sync   /dev/sda
       1       8       16        1      active sync   /dev/sdb
       2       8       32        2      active sync   /dev/sdc
       3       8       48        3      active sync   /dev/sdd
       5       8       64        4      active sync   /dev/sde
```

## 3. Создать GPT раздел, пять партиций и смонтировать их на диск

```bash
[root@otuslinux vagrant]# parted -s /dev/md0 mklabel gpt
[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 0% 20%
Information: You may need to update /etc/fstab.

[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 20% 40%
Information: You may need to update /etc/fstab.

[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 40% 60%
Information: You may need to update /etc/fstab.

[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 60% 80%
Information: You may need to update /etc/fstab.

[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 80% 100%
Information: You may need to update /etc/fstab.

[root@otuslinux vagrant]# for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=2048 blocks
50200 inodes, 200704 blocks
10035 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
25 block groups
8192 blocks per group, 8192 fragments per group
2008 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=2048 blocks
50800 inodes, 202752 blocks
10137 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
25 block groups
8192 blocks per group, 8192 fragments per group
2032 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=2048 blocks
51200 inodes, 204800 blocks
10240 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
25 block groups
8192 blocks per group, 8192 fragments per group
2048 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=2048 blocks
50800 inodes, 202752 blocks
10137 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
25 block groups
8192 blocks per group, 8192 fragments per group
2032 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=2048 blocks
50200 inodes, 200704 blocks
10035 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
25 block groups
8192 blocks per group, 8192 fragments per group
2008 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

[root@otuslinux vagrant]# mkdir -p /raid/part{1,2,3,4,5}
[root@otuslinux vagrant]# for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
[root@otuslinux vagrant]# mount
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime,seclabel)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
devtmpfs on /dev type devtmpfs (rw,nosuid,seclabel,size=499864k,nr_inodes=124966,mode=755)
securityfs on /sys/kernel/security type securityfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /dev/shm type tmpfs (rw,nosuid,nodev,seclabel)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,seclabel,gid=5,mode=620,ptmxmode=000)
tmpfs on /run type tmpfs (rw,nosuid,nodev,seclabel,mode=755)
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,seclabel,mode=755)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,xattr,release_agent=/usr/lib/systemd/systemd-cgroups-agent,name=systemd)
pstore on /sys/fs/pstore type pstore (rw,nosuid,nodev,noexec,relatime)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,net_prio,net_cls)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,perf_event)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,cpuacct,cpu)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,memory)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,cpuset)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,hugetlb)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,freezer)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,pids)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,blkio)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,seclabel,devices)
configfs on /sys/kernel/config type configfs (rw,relatime)
/dev/sdf1 on / type xfs (rw,relatime,seclabel,attr2,inode64,noquota)
selinuxfs on /sys/fs/selinux type selinuxfs (rw,relatime)
hugetlbfs on /dev/hugepages type hugetlbfs (rw,relatime,seclabel)
mqueue on /dev/mqueue type mqueue (rw,relatime,seclabel)
debugfs on /sys/kernel/debug type debugfs (rw,relatime)
systemd-1 on /proc/sys/fs/binfmt_misc type autofs (rw,relatime,fd=31,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=11543)
sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw,relatime)
tmpfs on /run/user/1000 type tmpfs (rw,nosuid,nodev,relatime,seclabel,size=101480k,mode=700,uid=1000,gid=1000)
/dev/md0p1 on /raid/part1 type ext4 (rw,relatime,seclabel,stripe=2048,data=ordered)
/dev/md0p2 on /raid/part2 type ext4 (rw,relatime,seclabel,stripe=2048,data=ordered)
/dev/md0p3 on /raid/part3 type ext4 (rw,relatime,seclabel,stripe=2048,data=ordered)
/dev/md0p4 on /raid/part4 type ext4 (rw,relatime,seclabel,stripe=2048,data=ordered)
/dev/md0p5 on /raid/part5 type ext4 (rw,relatime,seclabel,stripe=2048,data=ordered)
```

Чтобы изменения сохранили после перезагрузки, обновим /etc/fstab
```bash
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0" >> /etc/fstab ; done
[root@otuslinux vagrant]# cat /etc/fstab

#
# /etc/fstab
# Created by anaconda on Thu Apr 30 22:04:55 2020
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
UUID=1c419d6c-5064-4a2b-953c-05b2c67edb15 /                       xfs     defaults        0 0
/swapfile none swap defaults 0 0
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
#VAGRANT-END
/dev/md0p1 /raid/part1 ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0
/dev/md0p2 /raid/part2 ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0
/dev/md0p3 /raid/part3 ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0
/dev/md0p4 /raid/part4 ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0
/dev/md0p5 /raid/part5 ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0
```

## 4. Итоговый Vagrant файл
```
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :otuslinux => {
        :box_name => "centos/7",
        :ip_addr => '192.168.56.2',
        :disks => {
                :sata1 => {
                        :dfile => './sata1.vdi',
                        :size => 250,
                        :port => 1
                },
                :sata2 => {
                        :dfile => './sata2.vdi',
                        :size => 250, # Megabytes
                        :port => 2
                },
                :sata3 => {
                        :dfile => './sata3.vdi',
                        :size => 250,
                        :port => 3
                },
                :sata4 => {
                        :dfile => './sata4.vdi',
                        :size => 250, # Megabytes
                        :port => 4
                },
                :sata5 => {
                        :dfile => './sata5.vdi',
                        :size => 250, # Megabytes
                        :port => 5
                }

        }


  },
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

      config.vm.define boxname do |box|

          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s

          #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset

          box.vm.network "private_network", ip: boxconfig[:ip_addr]

          box.vm.provider :virtualbox do |vb|
                  vb.customize ["modifyvm", :id, "--memory", "1024"]
                  needsController = false
                  boxconfig[:disks].each do |dname, dconf|
                          unless File.exist?(dconf[:dfile])
                                vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size>
                                needsController =  true
                          end

                  end
                  if needsController == true
                     vb.customize ["storagectl", :id, "--name", "SATA", "--add", "sata" ]
                     boxconfig[:disks].each do |dname, dconf|
                         vb.customize ['storageattach', :id,  '--storagectl', 'SATA', '--port', dconf[:port], '--device', 0, '--ty>
                     end
                  end
          end
          box.vm.provision "shell", inline: <<-SHELL
mkdir -p ~root/.ssh
              cp ~vagrant/.ssh/auth* ~root/.ssh
              yum install -y mdadm smartmontools hdparm gdisk
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
                # хотя этот шаг можно пропустить
                for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
                # но тогда мы увидим разделы только после первой перезагрузки
                for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 rw,relatime,seclabel,stripe=2048,data=ordered 0 0" >> >

          SHELL

      end
  end
end

```

## 5. Создадим файл для ДЗ linuxpro-homework02.sh
```bash
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
```

