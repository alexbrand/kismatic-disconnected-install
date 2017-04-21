variable aws_region {
  description = "Region to use for AWS objects"
  default     = "us-east-1"
}

variable aws_ami {
  description = "The AMI to use for compute instances"
  default     = "ami-29f96d3e" # Ubuntu 16.04
}

variable key_name {
  description = "Name of the SSH key"
  default     = "KET Offline Demo Key"
}

variable public_key_path {
  description = "Path to the public SSH key"
  default     = "../ssh.key.pub"
}

variable private_key_path {
  description = "Path to the private SSH key that corresponds to the public SSH key"
  default     = "../ssh.key"
}
