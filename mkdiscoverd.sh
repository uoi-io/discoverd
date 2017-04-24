#!/bin/bash
#
# License: Apache
# Author: Gaetan Trellu - goldyfruit (gaetan.trellu@incloudus.com)
#
# Create a ramdisk based on Debian distribution and Busybox

# Variables
pkgs="nmap,linux-image-amd64,tcpdump,libpci3,dmidecode,ipmitool,hwdata,udev,httpie"
cmds="ncat tcpdump dmidecode biosdecode biosdevname udevadm ipmitool"
biosdevnameUrl="http://mirrors.kernel.org/ubuntu/pool/main/b/biosdevname"
biosdevnamePkg="biosdevname_0.4.1-0ubuntu8_amd64.deb"
busyboxVersion="1.26.2-defconfig-multiarch"
busyboxUrl="https://busybox.net/downloads/binaries/${busyboxVersion}"
debianFtpAddr="http://ftp.ca.debian.org/debian"
debianVersion="jessie"
debianArch="amd64"

# Prepare
mkdir -pv generated
cd discoverd
mkdir -pv dev proc sys tmp bin etc lib usr/share bin var sbin root lib64

# Get Busybox
curl -o bin/busybox ${busyboxUrl}/busybox-x86_64
chmod +x bin/busybox

# Bootstrap a Debian distribution with additional packages
sudo debootstrap --arch $debianArch --variant=minbase --include=${pkgs} $debianVersion debootstrap $debianFtpAddr
sudo curl -o debootstrap/root/${biosdevnamePkg} ${biosdevnameUrl}/${biosdevnamePkg}
sudo chroot debootstrap dpkg -i /root/${biosdevnamePkg}

# Copy commands and libraries from bootstrap to the ramdisk
for cmd in $cmds; do
    pathToCmd=$(sudo chroot debootstrap which $cmd)
    for lib in $(sudo chroot debootstrap ldd $pathToCmd | cut -d " " -f 3); do
        libDir=$(dirname $lib)
        if [ ! -d .${libDir} ]; then
            mkdir -pv .${libDir}
        fi
        sudo cp -avL debootstrap${lib} .${lib}
        if [ -L $lib ]; then
            realLib=$(ls -l $lib | awk '{ print $NF }')
            sudo cp -av ${libDir}/${realLib} .${libDir}/
        fi
    done
    cmdDir=$(dirname $pathToCmd)
    if [ ! -d .${cmdDir} ]; then
        mkdir -pv .${cmdDir}
    fi
    if [ -L debootstrap${pathToCmd} ]; then
        realCmd=$(ls -l debootstrap${pathToCmd} | awk '{ print $NF }')
        sudo cp -av debootstrap${realCmd} .${realCmd}
    else
        sudo cp -av debootstrap${pathToCmd} .${pathToCmd}
    fi
done

# Initialize Busybox in ramdisk
sudo chroot . /bin/busybox --install -s

# Copy the libc library in ramkdisk
ld=lib64/ld-linux-x86-64.so.2
if [ -L debootstrap/${ld} ]; then
    ldVersion=$(ls -l debootstrap/${ld} | awk '{ print $NF }')
    cp -av debootstrap${ldVersion} .${ldVersion}
    sudo chroot . /bin/ln -sf ${ldVersion} /lib64/ld-linux-x86-64.so.2
fi

# Copy hwdata directory and hwdb.bin in ramdisk
sudo chroot debootstrap cp -avL /usr/share/hwdata /root
sudo cp -av debootstrap/root/hwdata ./usr/share/
pushd debootstrap
hwdbDir=$(sudo find . -type f -name hwdb.bin -exec sh -c 'dirname {} | sed "s/.//"' \;)
popd
mkdir -pv .${hwdbDir}
sudo cp -av debootstrap${hwdbDir}/hwdb.bin .${hwdbDir}

# Copy kernel modules in ramkdisk
sudo mv -v debootstrap/lib/modules ./lib/

# Get the kernel that should be used with the generated ramdisk
sudo cp -av debootstrap/boot/vmlinuz-* ../generated/vmlinuz
sudo rm -rf debootstrap
sudo chown root:root -R .

# Generate the discoverd compressed ramdisk
find . | cpio -H newc -o | gzip -v -c > ../generated/discoverd.img.gz

sudo chown $USER:$USER -R . ../generated
