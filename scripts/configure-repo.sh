#!/bin/bash

set -e

MIRROR_IP=$1

# Need to disable unaccessible repos
mv /etc/yum.repos.d /etc/yum.repos.d.inaccessible

mkdir /etc/yum.repos.d

cat > /etc/yum.repos.d/kismatic.repo <<EOF
[kismatic]
baseurl = http://$MIRROR_IP/kismatic
gpgcheck = 0
name = Kismatic Packages
EOF

cat > /etc/yum.repos.d/mirror-rhel.repo <<EOF
[mirror-rhel]
baseurl = http://$MIRROR_IP/rhui-REGION-rhel-server-releases
gpgcheck = 0
name = RHEL Packages Mirror
EOF

cat > /etc/yum.repos.d/gluster.repo <<EOF
[mirror-gluster]
baseurl = http://$MIRROR_IP/gluster
gpgcheck = 0
name = Gluster Packages Mirror
EOF