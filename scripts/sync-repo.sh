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
reposync -l --repoid=kismatic --download_path=/var/www/html \
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

# Setup gluster repo
cat > /etc/yum.repos.d/gluster.repo <<EOF
[gluster]
baseurl = http://buildlogs.centos.org/centos/7/storage/x86_64/gluster-3.8/
gpgcheck = 0
name = Gluster repo
EOF

# Sync glusterfs repo
# Not syncing latest only, as we need an older version of gluster...
reposync -l --repoid=gluster --download_path=/var/www/html \
  --downloadcomps --download-metadata

createrepo -v /var/www/html/gluster/

chown -R apache /var/www/html/gluster/
chgrp -R apache /var/www/html/gluster/

systemctl start httpd
