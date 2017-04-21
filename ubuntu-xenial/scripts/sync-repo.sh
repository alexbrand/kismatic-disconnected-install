#!/bin/bash
set -e 

# Get aptly
echo "deb http://repo.aptly.info/ squeeze main" >> /etc/apt/sources.list
wget -qO - https://www.aptly.info/pubkey.txt | sudo apt-key add -

# Install dependencies
apt-get -y update
apt-get -y upgrade
apt-get -y install apt-mirror aptly # apache2

# Get gpg key of kismatic repo
wget -O - https://s3.amazonaws.com/kismatic-packages-deb/public.key | gpg --no-default-keyring --keyring trustedkeys.gpg --import

# Create mirror of kismatic repo
aptly mirror create kismatic https://kismatic-packages-deb.s3-accelerate.amazonaws.com kismatic-xenial
aptly mirror update kismatic
aptly snapshot create kismatic from mirror kismatic

# Mirror the main ubuntu repo
# Need retry loop here for some reason...
n=0
while true
do
  gpg --no-default-keyring --keyring trustedkeys.gpg --keyserver keys.gnupg.net --recv-keys 40976EAF437D05B5 3B4FE6ACC0B21F32 && break || true
  n=$((n+1))
  if [ $n -ge 3 ]; then exit 1; fi
  echo "Retrying..."
  sleep 5
done

sudo aptly mirror create \
  -architectures=amd64 \
  -filter="bridge-utils|nfs-common|socat|libltdl7|python2.7" \
  -filter-with-deps \
  ubuntu-main http://archive.ubuntu.com/ubuntu xenial main universe
aptly mirror update ubuntu-main
aptly snapshot create ubuntu-main from mirror ubuntu-main
# aptly publish snapshot -batch -skip-signing=true -distribution=xenial ubuntu-main

# Merge the repos
aptly snapshot merge mirror-repo kismatic ubuntu-main

# Publish the mirror
aptly publish snapshot -batch -skip-signing=true -distribution=xenial mirror-repo

# Serve the repositories
cat <<EOF > /etc/systemd/system/aptly.service
[Service]
Type=simple
ExecStart=/usr/bin/aptly serve -config=/home/ubuntu/.aptly.conf -listen=:80
EOF

systemctl daemon-reload
systemctl start aptly.service

# Setup upstream Kismatic repo
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://kismatic-packages-deb.s3-accelerate.amazonaws.com kismatic-xenial main
EOF

# Update cache
apt-get -y update

cat <<EOF > /etc/apt/mirror.list
############# config ##################
#
# set base_path    /var/spool/apt-mirror
#
# set mirror_path  $base_path/mirror
# set skel_path    $base_path/skel
# set var_path     $base_path/var
# set cleanscript $var_path/clean.sh
# set defaultarch  <running host architecture>
# set postmirror_script $var_path/postmirror.sh
# set run_postmirror 0
set nthreads     20
set _tilde 0
#
############# end config ##############

deb http://archive.ubuntu.com/ubuntu xenial main
#deb http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse
#deb http://archive.ubuntu.com/ubuntu xenial-security main restricted universe multiverse
#deb http://archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse
#deb http://archive.ubuntu.com/ubuntu xenial-proposed main restricted universe multiverse
#deb http://archive.ubuntu.com/ubuntu xenial-backports main restricted universe multiverse

# Mirror kismatic repo
deb https://kismatic-packages-deb.s3-accelerate.amazonaws.com kismatic-xenial main

#deb-src http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse
#deb-src http://archive.ubuntu.com/ubuntu xenial-security main restricted universe multiverse
#deb-src http://archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse
#deb-src http://archive.ubuntu.com/ubuntu xenial-proposed main restricted universe multiverse
#deb-src http://archive.ubuntu.com/ubuntu xenial-backports main restricted universe multiverse

clean http://archive.ubuntu.com/ubuntu
clean https://kismatic-packages-deb.s3-accelerate.amazonaws.com
EOF

# Download packages to mirror
#apt-mirror

# Expose repo over HTTP
#ln -s /var/spool/apt-mirror/mirror/kismatic-packages-deb.s3-accelerate.amazonaws.com /var/www/html/kismatic

# # Perform repository sync - this takes some time...
# reposync -l -n --repoid=kismatic --download_path=/var/www/html \
#  --downloadcomps --download-metadata

# createrepo -v  /var/www/html/kismatic/ 

# chown -R apache /var/www/html/kismatic
# chgrp -R apache /var/www/html/kismatic

# # Sync rhel repo - this takes some time...
# # We need this to get some transitive dependencies...
# reposync -l -n --repoid=rhui-REGION-rhel-server-releases --download_path=/var/www/html \
#   --downloadcomps --download-metadata

# createrepo -v /var/www/html/rhui-REGION-rhel-server-releases/

# chown -R apache /var/www/html/rhui-REGION-rhel-server-releases/
# chgrp -R apache /var/www/html/rhui-REGION-rhel-server-releases/

# # Setup gluster repo
# cat > /etc/yum.repos.d/gluster.repo <<EOF
# [gluster]
# baseurl = http://buildlogs.centos.org/centos/7/storage/x86_64/gluster-3.8/
# gpgcheck = 0
# name = Gluster repo
# EOF

# # Sync glusterfs repo
# # Not syncing latest only, as we need an older version of gluster...
# reposync -l --repoid=gluster --download_path=/var/www/html \
#   --downloadcomps --download-metadata

# createrepo -v /var/www/html/gluster/

# chown -R apache /var/www/html/gluster/
# chgrp -R apache /var/www/html/gluster/

# systemctl start httpd