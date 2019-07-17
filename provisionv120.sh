#!/bin/bash

set -ex
set -o pipefail

# Ensure this script is run as root
if [ "$(id -u)" -ne "0" ]; then
  exec sudo -E $0 "$@"
fi

# Global variable definition
vyos_iso_local=/tmp/vyos.iso
# vyos_iso_url=http://packages.vyos.net/iso/release/${VYOS_VERSION}/vyos-${VYOS_VERSION}-amd64.iso
vyos_iso_url=${VYOS_ISO_URL}

CD_ROOT=/mnt/cdrom
CD_SQUASH_ROOT=/mnt/cdsquash
SQUASHFS_IMAGE="${CD_ROOT}/live/filesystem.squashfs"

VOLUME_DRIVE=/dev/xvdf
ROOT_PARTITION=${VOLUME_DRIVE}1

WRITE_ROOT=/mnt/wroot
READ_ROOT=/mnt/squashfs
INSTALL_ROOT=/mnt/inst_root

# # Fetch GPG key and VyOS image
curl -sSLfo ${vyos_iso_local} ${vyos_iso_url}
# curl -sSLfo ${vyos_iso_local}.asc ${vyos_iso_url}.asc
# curl -sSLf http://packages.vyos.net/vyos-release.gpg | gpg --import

# # Verify ISO is valid
# gpg --verify ${vyos_iso_local}.asc ${vyos_iso_local}

# Mount ISO
mkdir -p ${CD_ROOT}
mount -t iso9660 -o loop,ro ${vyos_iso_local} ${CD_ROOT}

# Verify files inside ISO image
cd ${CD_ROOT}
md5sum -c md5sum.txt

# Mount squashfs image from ISO
mkdir -p ${CD_SQUASH_ROOT}
mount -t squashfs -o loop,ro ${SQUASHFS_IMAGE} ${CD_SQUASH_ROOT}

# Obtain version information
vyos_version=$(cat ${CD_SQUASH_ROOT}/opt/vyatta/etc/version | awk '{print $2}' | tr + -)
echo "VyOs version is :${vyos_version}"
# vyos_version=$(awk '/^vyatta-version/{print $2}' ${CD_ROOT}/live/filesystem.packages)

# Prepare EBS volume
parted --script ${VOLUME_DRIVE} mklabel msdos
parted --script --align optimal ${VOLUME_DRIVE} mkpart primary 0% 100%
mkfs.ext4 ${ROOT_PARTITION}
parted --script ${VOLUME_DRIVE} set 1 boot
mkdir -p ${WRITE_ROOT}
mount -t ext4 ${ROOT_PARTITION} ${WRITE_ROOT}

# Create installation directory
mkdir -p ${WRITE_ROOT}/boot/${vyos_version}/live-rw

# Copy files from ISO to filesystem
cp -p ${SQUASHFS_IMAGE} ${WRITE_ROOT}/boot/${vyos_version}/${vyos_version}.squashfs
find ${CD_SQUASH_ROOT}/boot -maxdepth 1  \( -type f -o -type l \) -exec cp -dp {} ${WRITE_ROOT}/boot/${vyos_version}/ \;

# Mount squashfs from filesystem
mkdir -p ${READ_ROOT}
mount -t squashfs -o loop,ro ${WRITE_ROOT}/boot/${vyos_version}/${vyos_version}.squashfs ${READ_ROOT}

# Set up union root for post installation tasks
mkdir -p ${INSTALL_ROOT}
mkdir -p ${WRITE_ROOT}/boot/${vyos_version}/work
mount -t overlay -o "noatime,upperdir=${WRITE_ROOT}/boot/${vyos_version}/live-rw,lowerdir=${READ_ROOT},workdir=${WRITE_ROOT}/boot/${vyos_version}/work" none ${INSTALL_ROOT}

## ---- VyOS configuration ----
# Make sure that config partition marker exists
touch ${INSTALL_ROOT}/opt/vyatta/etc/config/.vyatta_config


# Copy the default config for EC2 to the installed image
cat -s <<EOF > ${INSTALL_ROOT}/opt/vyatta/etc/config/config.boot
service {
    ssh {
        client-keepalive-interval "180"
        disable-password-authentication {
        }
        port "22"
    }
}
system {
    host-name VyOS-AMI
    login {
        user vyos {
            authentication {
                encrypted-password "*"
                plaintext-password ""
            }
            level admin
        }
    }
    syslog {
        global {
            facility all {
                level notice
            }
            facility protocols {
                level debug
            }
        }
    }
    ntp {
        server "0.pool.ntp.org"
        server "1.pool.ntp.org"
        server "2.pool.ntp.org"
    }
    config-management {
        commit-revisions 100
    }
    console {
        device ttyS0 {
            speed 9600
        }
    }
}
interfaces {
    ethernet eth0 {
        address dhcp
    }
    loopback lo
}
EOF

# Install ec2 init script. This isn't actually used, but left here for easy development of this script.
cp /tmp/ec2-fetch-ssh-public-key ${INSTALL_ROOT}/etc/init.d/ec2-fetch-ssh-public-key

### Install GRUB boot loader

# Create GRUB directory
mkdir -p ${WRITE_ROOT}/boot/grub

# Mount and bind required filesystems for grub installation
mount --bind /dev ${INSTALL_ROOT}/dev
mount --bind /proc ${INSTALL_ROOT}/proc
mount --bind /sys ${INSTALL_ROOT}/sys
mount --bind ${WRITE_ROOT} ${INSTALL_ROOT}/boot

# Install grub to boot sector
chroot ${INSTALL_ROOT} grub-install --no-floppy --root-directory=/boot ${VOLUME_DRIVE}
cat -s <<EOF > ${WRITE_ROOT}/boot/grub/grub.cfg
set default=0
set timeout=0

menuentry "VyOS AMI (HVM) ${vyos_version}" {
  linux /boot/${vyos_version}/vmlinuz boot=live selinux=0 vyos-union=/boot/${vyos_version} console=tty1
  initrd /boot/${vyos_version}/initrd.img
}
EOF

# Create the persistence config
cat -s <<EOF > ${WRITE_ROOT}/persistence.conf
/ union
EOF

# ---- Unmount all mounts ----
cd
for path in boot dev sys proc; do
  umount ${INSTALL_ROOT}/${path}
done
umount ${INSTALL_ROOT}
rm -rf ${WRITE_ROOT}/boot/${vyos_version}/work
umount ${READ_ROOT}
umount ${WRITE_ROOT}
umount ${CD_SQUASH_ROOT}
umount ${CD_ROOT}
