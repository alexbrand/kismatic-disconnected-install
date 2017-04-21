output "mirror_ip" {
  value = "${aws_instance.mirror_node.public_ip}"
}

output "etcd" {
  value = "\t\thost: ${aws_instance.etcd.private_dns}\n\t\tip: ${aws_instance.etcd.private_ip}"
}

output "master" {
  value = "\thost: ${aws_instance.master.private_dns}\n\t\tip: ${aws_instance.master.private_ip}"
}

output "loadbalanced" {
  value = "\tload_balanced_fqdn: ${aws_instance.master.private_ip}\n\tload_balanced_short_name: ${aws_instance.master.private_ip}"
}

output "worker" {
  value = "\thost: ${aws_instance.worker.private_dns}\n\t\tip: ${aws_instance.worker.private_ip}"
}
/*
output "storage" {
  value = "\thost: ${aws_instance.storage.private_dns}\n\t\tip: ${aws_instance.storage.private_ip}"
}
*/
