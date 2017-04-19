# Kismatic Disconnected Install

This repository contains a sample deployment of Kubernetes using Kismatic 
on infrastructure that is completely disconnected from the Internet. We
will use RHEL 7 machines on AWS in this guide.

Kismatic provides DEB and RPM packages for all it's dependencies. This enables
an enterprise to mirror the packages using their internal systems and processes.

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

## Getting started
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


5. Access the "mirror" node using SSH:
```
ssh ec2-user@$(terraform output mirror_ip) -i ssh.key
```

6. Edit the `kismatic-cluster.yaml` file using terraform's output. You should
be able to copy/paste the information into the right spots.

7. Run `./kismatic install validate` to make sure all is good to go.

8. Run `./kismatic install apply` to build your Kubernetes cluster.
