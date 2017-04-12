#!/bin/bash
set -e 

# Install dependencies
yum -y update
yum -y install yum-utils createrepo httpd

# Disable SELinux for httpd
setenforce 0

# Setup upstream Kismatic repo
cat > /etc/yum.repos.d/kismatic.repo <<EOF
[kismatic]
baseurl = https://kismatic-packages-rpm.s3-accelerate.amazonaws.com
gpgcheck = 1
gpgkey = https://kismatic-packages-rpm.s3-accelerate.amazonaws.com/public.key
name = Kismatic Packages
EOF

# Perform repository sync - this takes some time...
reposync -l -n --repoid=kismatic --download_path=/var/www/html \
 --downloadcomps --download-metadata

createrepo -v  /var/www/html/kismatic/ 

chown -R apache /var/www/html/kismatic
chgrp -R apache /var/www/html/kismatic

# Sync rhel repo - this takes some time...
# We need this to get some transitive dependencies...
reposync -l -n --repoid=rhui-REGION-rhel-server-releases --download_path=/var/www/html \
  --downloadcomps --download-metadata

createrepo -v /var/www/html/rhui-REGION-rhel-server-releases/

chown -R apache /var/www/html/rhui-REGION-rhel-server-releases/
chgrp -R apache /var/www/html/rhui-REGION-rhel-server-releases/

systemctl start httpd