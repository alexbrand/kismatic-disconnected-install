# Kismatic Disconnected Install

This repository contains a sample deployment of Kubernetes using Kismatic 
on infrastructure that is completely disconnected from the Internet. We
will use RHEL 7 machines on AWS in this guide.

Kismatic provides DEB and RPM packages for all it's dependencies. This enables
an enterprise to mirror the packages using their internal systems and processes.

Kismatic also maintains a special DEB/RPM package that includes all the docker images
that Kismatic depends on. This package can be used to seed a private internal docker
registry. The seeding can be manually performed before the installation, or the user can let
Kismatic seed the private registry. In this workshop, we will let Kismatic seed
the private registry.

The first thing we will do is install Kismatic v1.3.0, which ships Kubernetes
v1.6.0. Once our initial cluster is setup with no internet access, we will use Kismatic
to perform a disconnected upgrade to Kismatic v1.3.2, which ships Kubernetes v1.6.2.

The initial installation will showcase a disconnected installation with pre-installed
Kismatic packages. This is to showcase the scenario where an AMI has already been pre-baked
with all the dependencies. The packages are pre-installed on the node with Terraform.

The upgrade process will show a disconnected upgrade that uses a private RPM repository
that has been synced with Kismatic's repo. This private RPM repo also includes all the required
transitive dependencies.

## Requirements
* Terraform
* AWS account and API secrets.

## Deployment
In this setup, the following machines are created:
* One "mirror" node: This node will act as the internal package repository.
This node *does* have internet access. For simplicity, this node is also where
we will run `kismatic`.
* One "etcd" node: No internet access
* One "master" node: No internet access
* One "worker" node: No internet access
* One "storage" node: No internet access

## Limitations / Known Issues
* Transitive dependencies must also be mirrored. For now, we are mirroring the 
entire `RHEL server releases` repository, which is wasteful and slow.

# Infrastructure setup
1. Create an SSH keypair with no password:
```
ssh-keygen -t rsa -b 4096 -f ssh.key
```

2. Export the AWS credentials to your environment:
```
export AWS_ACCESS_KEY_ID=#Your access key here
export AWS_SECRET_ACCESS_KEY=#Your secret here
```

3. Preview the changes that will be performed on AWS:
```
terraform plan
```

4. Provision the infrastructure (This takes some time):
```
terraform apply
```
Once the infrastructure is provisioned, Terraform will print information that 
will be useful when building our kismatic plan file.

## Cluster Installation
1. Access the "mirror" node using SSH:
```
ssh ec2-user@$(terraform output mirror_ip) -i ssh.key
```
2. Let's use Kismatic v1.3.0:
```
cd kismatic
```

3. Edit the `kismatic-cluster.yaml` file using terraform's output. You should
be able to copy/paste the information into the right spots.

4. Run `./kismatic install validate` to make sure all is good to go.

5. Run `./kismatic install apply` to build your Kubernetes cluster.

## Cluster Upgrade
1. Access the "mirror" node using SSH if you don't already have an SSH session.

2. Go into the Kismatic v1.3.0 directory:
```
cd kismatic
```

3. Copy the plan file and the generated assets to the new kismatic version:
```
cp -r generated/ kismatic-cluster.yaml ../kismatic2
```

3. Let's switch over to Kismatic v1.3.2:
```
cd kismatic2
```

4. We will let kismatic install the packages from the private repository for us. 
Edit the `kismatic-cluster.yaml` file to enable package installation, by setting 
the `allow_package_installation` option to `true`.

5. Do a dry-run to make sure that everything is looking good:
```
./kismatic upgrade offline --dry-run
```

6. Proceed with the disconnected upgrade:
```
./kismatic upgrade offline
```

7. Once the upgrade is done, you should have a Kubernetes cluster with v1.6.2.
You may use the following command to verify:
```
./kismatic ssh master -- sudo kubectl version
```
