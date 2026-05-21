#!/bin/bash

mount /var
mount /home

# Configuring user: root ...
passwd -l root
usermod -s /sbin/nologin root

# Configuring user: prokop ...
useradd -m -s /bin/bash prokop

# Configure SSH keys for prokop
mkdir -m 700 -p /home/prokop/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMY0/DKivPtnP/c56SCp3klOcR0ls9DC7tzz0KdT3HKM prokop@rdck.dev" > /home/prokop/.ssh/authorized_keys

# Set correct ownership, permissions, AND SELinux contexts
chown -R prokop:prokop "/home/prokop/.ssh"
chmod 600 "/home/prokop/.ssh/authorized_keys"
restorecon -R "/home/prokop/.ssh"

# Prokop can sudo
echo "prokop ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/prokop
chmod 440 /etc/sudoers.d/prokop

# Hostname
echo "experiler" > /etc/hostname
chmod 644 /etc/hostname

# Language
echo "LANG=en_US.UTF-8" > /etc/locale.conf
chmod 644 /etc/locale.conf

# Network settings 
mkdir -p /etc/NetworkManager/system-connections/
cat >/etc/NetworkManager/system-connections/Universal.nmconnection <<-EOF
[connection]
id=Universal
type=ethernet

[ipv4]
dns-search=
method=auto

[ipv6]
dns-search=
addr-gen-mode=eui64
method=auto
EOF
chmod 600 /etc/NetworkManager/system-connections/Universal.nmconnection

# Network settings 
mkdir -p /etc/NetworkManager/conf.d/
cat >/etc/NetworkManager/conf.d/noauto.conf  <<-EOF
[main]
# Do not do automatic (DHCP/SLAAC) configuration on ethernet devices
# with no other matching connections.
no-auto-default=*
EOF
chmod 644 /etc/NetworkManager/conf.d/noauto.conf

# Lock down sshd
mkdir -p /etc/ssh/sshd_config.d/
cat > /etc/ssh/sshd_config.d/10-hardened.conf <<-EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers prokop
EOF
chmod 644 /etc/ssh/sshd_config.d/10-hardened.conf

# start Service sshd.service
systemctl enable sshd.service

# Explicitly stop jeos-firstboot from blocking the boot process
systemctl mask jeos-firstboot.service

# Keyboard
test -f /etc/vconsole.conf && FONT=$(grep ^FONT= /etc/vconsole.conf)
systemd-firstboot --force --keymap=us
test -n "$FONT" && echo "$FONT" >> /etc/vconsole.conf

# Timezone
systemd-firstboot --force --timezone=Europe/Prague

## Reboot after setup
cat > /etc/systemd/system/firstbootreboot.service <<-EOF
[Unit]
Description=First Boot Reboot

[Service]
Type=oneshot
ExecStart=rm /etc/systemd/system/firstbootreboot.service
ExecStart=rm /etc/systemd/system/default.target.wants/firstbootreboot.service
ExecStart=systemctl reboot

[Install]
WantedBy=default.target
EOF
systemctl enable firstbootreboot.service

umount /var
umount /home
