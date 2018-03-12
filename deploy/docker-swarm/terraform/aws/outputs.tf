output "master_address" {
  value = "${aws_instance.docker_swarm_manager_init.public_ip}"
}

output "worker_addresses" {
  value = ["${aws_instance.docker_swarm_workers.*.private_ip}"]
}

output "manager_addresses" {
  value = "${aws_instance.docker_swarm_managers.*.public_ip}"
}
