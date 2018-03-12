terraform {
  required_version = "~> 0.11.0"
  backend          "s3"             {}
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_instance" "docker_swarm_manager_init" {
  instance_type               = "${var.instance_type}"
  ami                         = "${data.aws_ami.docker_ami.id}"
  key_name                    = "${var.private_key_name}"
  vpc_security_group_ids      = ["${aws_security_group.docker_swarm_sg.id}", "${aws_security_group.docker_swarm_managers_sg.id}"]
  associate_public_ip_address = "true"

  tags {
    Name        = "docker-swarm-leader-${var.environment}-${var.git_commit}"
    Environment = "${var.environment}"
    GitCommit   = "${var.git_commit}"
    GitBranch   = "${var.git_branch}"
    Version     = "${var.version}"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    volume_size = "${var.manager_volume_size}"
  }

  lifecycle {
    ignore_changes = ["ebs_block_device"]
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "docker swarm init",
    ]
  }
}

resource "aws_instance" "docker_swarm_managers" {
  depends_on                  = ["null_resource.create_join_scripts"]
  count                       = "${var.additional_manager_nodes}"
  instance_type               = "${var.instance_type}"
  ami                         = "${data.aws_ami.docker_ami.id}"
  key_name                    = "${var.private_key_name}"
  vpc_security_group_ids      = ["${aws_security_group.docker_swarm_sg.id}", "${aws_security_group.docker_swarm_managers_sg.id}"]
  associate_public_ip_address = "true"

  tags {
    Name        = "docker-swarm-manager-${var.environment}-${var.git_commit}"
    Environment = "${var.environment}"
    GitCommit   = "${var.git_commit}"
    GitBranch   = "${var.git_branch}"
    Version     = "${var.version}"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    volume_size = "${var.manager_volume_size}"
  }

  lifecycle {
    ignore_changes = ["ebs_block_device"]
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source      = "join_manager.sh"
    destination = "/tmp/join_manager.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "chmod +x /tmp/join_manager.sh",
      "/tmp/join_manager.sh",
    ]
  }
}

resource "aws_instance" "docker_swarm_workers" {
  depends_on             = ["null_resource.create_join_scripts"]
  count                  = "${var.num_nodes}"
  instance_type          = "${var.instance_type}"
  ami                    = "${data.aws_ami.docker_ami.id}"
  key_name               = "${var.private_key_name}"
  vpc_security_group_ids = ["${aws_security_group.docker_swarm_sg.id}"]

  tags {
    Name        = "docker-swarm-worker-${var.environment}-${var.git_commit}"
    Environment = "${var.environment}"
    GitCommit   = "${var.git_commit}"
    GitBranch   = "${var.git_branch}"
    Version     = "${var.version}"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    volume_size = "${var.worker_volume_size}"
  }

  lifecycle {
    ignore_changes = ["ebs_block_device"]
  }

  connection {
    user         = "ubuntu"
    private_key  = "${file("${var.private_key_path}")}"
    bastion_host = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "file" {
    source      = "join_worker.sh"
    destination = "/tmp/join_worker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "chmod +x /tmp/join_worker.sh",
      "/tmp/join_worker.sh",
      "scope launch ${aws_instance.docker_swarm_manager_init.public_ip}",
    ]
  }
}

resource "null_resource" "create_join_scripts" {
  depends_on = ["aws_instance.docker_swarm_manager_init"]

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host        = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "local-exec" {
    command = "TOKEN=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_instance.docker_swarm_manager_init.public_ip} docker swarm join-token -q worker); echo \"#!/usr/bin/env bash\ndocker swarm join --token $TOKEN ${aws_instance.docker_swarm_manager_init.public_ip}:2377\" >| join_worker.sh"
  }

  provisioner "local-exec" {
    command = "TOKEN=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_instance.docker_swarm_manager_init.public_ip} docker swarm join-token -q manager); echo \"#!/usr/bin/env bash\ndocker swarm join --token $TOKEN ${aws_instance.docker_swarm_manager_init.public_ip}:2377\" >| join_manager.sh"
  }
}

resource "null_resource" "deploy_docker_stack" {
  depends_on = ["aws_instance.docker_swarm_manager_init"]

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host        = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p resources/nginx",
    ]
  }

  provisioner "file" {
    source      = "${var.docker_compose_file}"
    destination = "docker-compose.yml"
  }

  provisioner "file" {
    source      = "${var.nginx_conf}"
    destination = "nginx.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "docker-compose -f docker-compose.yml pull",
      "docker stack deploy -c docker-compose.yml helloworld",
    ]
  }
}

resource "null_resource" "deploy_monitoring_stack" {
  depends_on = ["aws_instance.docker_swarm_workers"]

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host        = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "file" {
    source      = "monitoring"
    destination = "monitoring"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p monitoring/data/prometheus",
      "docker-compose -f monitoring/monitoring-stack.yml pull",
      "docker stack deploy -c monitoring/monitoring-stack.yml monitoring",
    ]
  }
}

resource "null_resource" "launch_weave_scope" {
  depends_on = ["aws_instance.docker_swarm_manager_init"]

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host        = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "scope launch ${join(" ", aws_instance.docker_swarm_workers.*.private_ip)}",
      "curl https://getcaddy.com | bash -s personal http.ipfilter,http.prometheus",
      "echo \":4041 { \nbasicauth / ${var.admin_user} ${var.admin_password} \nproxy / localhost:4040 { \nwebsocket \n} \nerrors stderr \ntls off \n}\" > Caddyfile.scope",
      "sleep 1",
      "nohup caddy -conf Caddyfile.scope &",
      "sleep 1",
    ]
  }
}

resource "null_resource" "cleanup" {
  depends_on = ["aws_instance.docker_swarm_manager_init", "aws_instance.docker_swarm_workers", "aws_instance.docker_swarm_managers"]

  provisioner "local-exec" {
    command = "rm -f -- join_worker.sh"
  }

  provisioner "local-exec" {
    command = "rm -f -- join_manager.sh"
  }
}
