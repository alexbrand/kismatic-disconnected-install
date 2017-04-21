#!/bin/bash
set -e

MIRROR_IP=$1

# Backup the original sources list
mv /etc/apt/sources.list /etc/apt/sources.list.bk

# Add mirror ip as the only source
cat > /etc/apt/sources.list <<EOF
deb http://$MIRROR_IP/ kismatic-xenial main
EOF

apt-get -y update