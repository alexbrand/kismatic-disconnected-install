provider "aws" {
  region = "us-east-1"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create a security group with no internet access
resource "aws_security_group" "block_internet" {
  name        = "ket-no-internet"
  description = "Security group for KET disconnected install demo. To be applied to KET nodes"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow connectivity between nodes in the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow connectivity between nodes in the VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

# Create a security group that allows egress internet traffic.
# This will be required for mirroring the Kismatic repos on one
# of our machines.
resource "aws_security_group" "allow_internet" {
  name        = "ket-allow-internet"
  description = "Security group for KET disconnected install demo that allows Internet access"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All access from within VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# This node will have internet access to be able to download
# all kismatic packages and create a mirror repo.
# This is also the node we will use for running KET.
resource "aws_instance" "mirror_node" {
  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  tags {
    ProvisionedBy = "Terraform-KET-Offline-Demo"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  instance_type          = "t2.medium"
  ami                    = "${var.aws_ami}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_internet.id}"]
  subnet_id              = "${aws_subnet.default.id}"

  # Setup a yum mirror for kismatic packages
  provisioner "file" {
    source      = "./scripts/sync-repo.sh"
    destination = "/tmp/sync-repo.sh"
  }

  # Run sync repo script and download kismatic
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/sync-repo.sh",
      "sudo /tmp/sync-repo.sh",
      "sudo yum install -y wget",
      "wget https://github.com/apprenda/kismatic/releases/download/v1.3.0/kismatic-v1.3.0-linux-amd64.tar.gz",
      "mkdir ~/kismatic",
      "tar -C ~/kismatic -xvf kismatic-v1.3.0-linux-amd64.tar.gz",
    ]
  }

  # Copy plan file over
  provisioner "file" {
    source      = "./kismatic-cluster.yaml"
    destination = "~/kismatic/kismatic-cluster.yaml"
  }

  provisioner "file" {
    source      = "${var.private_key_path}"
    destination = "~/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 ~/.ssh/id_rsa",
    ]
  }
}

# These are the nodes that will make up the kubernetes cluster.
# These nodes don't have access to the internet
resource "aws_instance" "etcd" {
  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  tags {
    KismaticRole  = "etcd"
    ProvisionedBy = "Terraform-KET-Offline-Demo"
  }

  instance_type          = "t2.small"
  ami                    = "${var.aws_ami}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.block_internet.id}"]
  subnet_id              = "${aws_subnet.default.id}"

  # Configure the mirror repo on the nodes
  provisioner "file" {
    source      = "./scripts/configure-repo.sh"
    destination = "/tmp/configure-repo.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/configure-repo.sh",
      "sudo /tmp/configure-repo.sh ${aws_instance.mirror_node.private_ip}",
      "sudo yum install -y --disablerepo=* --enablerepo=kismatic,mirror-rhel etcd",
    ]
  }
}

# Create two nodes that will have kubernetes components. One master node and
# one worker node.
resource "aws_instance" "master" {
  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  tags {
    KismaticRole  = "master"
    ProvisionedBy = "Terraform-KET-Offline-Demo"
  }

  instance_type          = "t2.small"
  ami                    = "${var.aws_ami}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.block_internet.id}"]
  subnet_id              = "${aws_subnet.default.id}"

  # Configure the mirror repo on the nodes
  provisioner "file" {
    source      = "./scripts/configure-repo.sh"
    destination = "/tmp/configure-repo.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/configure-repo.sh",
      "sudo /tmp/configure-repo.sh ${aws_instance.mirror_node.private_ip}",
      "sudo yum install -y --disablerepo=* --enablerepo=kismatic,mirror-rhel docker-engine kubelet kubectl kismatic-offline",
    ]
  }
}

resource "aws_instance" "worker" {
  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  tags {
    KismaticRole  = "worker"
    ProvisionedBy = "Terraform-KET-Offline-Demo"
  }

  instance_type          = "t2.small"
  ami                    = "${var.aws_ami}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.block_internet.id}"]
  subnet_id              = "${aws_subnet.default.id}"

  # Configure the mirror repo on the nodes
  provisioner "file" {
    source      = "./scripts/configure-repo.sh"
    destination = "/tmp/configure-repo.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/configure-repo.sh",
      "sudo /tmp/configure-repo.sh ${aws_instance.mirror_node.private_ip}",
      "sudo yum install -y --disablerepo=* --enablerepo=kismatic,mirror-rhel docker-engine kubelet kubectl",
    ]
  }
}


resource "aws_instance" "storage" {
  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  tags {
    KismaticRole  = "worker"
    ProvisionedBy = "Terraform-KET-Offline-Demo"
  }

  instance_type          = "t2.small"
  ami                    = "${var.aws_ami}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.block_internet.id}"]
  subnet_id              = "${aws_subnet.default.id}"

  # Configure the mirror repo on the nodes
  provisioner "file" {
    source      = "./scripts/configure-repo.sh"
    destination = "/tmp/configure-repo.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/configure-repo.sh",
      "sudo /tmp/configure-repo.sh ${aws_instance.mirror_node.private_ip}",
      "sudo yum install -y --disablerepo=* --enablerepo=kismatic,mirror-rhel,mirror-gluster docker-engine kubelet kubectl glusterfs-server-3.8.7-1.el7",
      # KET preflight checks fail if this is running on port 111
      "sudo systemctl disable rpcbind.socket",
      "sudo systemctl stop rpcbind.socket"
    ]
  }
}
