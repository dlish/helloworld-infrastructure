# terraform plan \
#   -var 'access_key=foo' \
#   -var 'secret_key=bar'

variable "region" {
  default = "us-west-1"
}

variable "additional_manager_nodes" {
  description = "Additional number of manager nodes (swarm always created with at least 1 manager)"
  default     = "0"
}

variable "num_nodes" {
  description = "Number of worker nodes"
  default     = "0"
}

variable "availability_zones" {
  description = "Name of the availability zones to use"
  default     = ["us-west-1b"]
}

variable "private_key_name" {
  description = "Name of private_key"
  default     = "dlish27"
}

variable "private_key_path" {
  description = "Path to file containing private key"
  default     = "~/.ssh/dlish27.pem"
}

variable "instance_type" {
  description = "AWS Instance size"
  default     = "t2.micro"
}

variable "environment" {
  description = "Environment type"
  default     = "staging"
}

variable "git_commit" {
  description = "Git Commit Short ID"
  default     = ""
}

variable "git_branch" {
  description = "Git Branch"
  default     = ""
}

variable "version" {
  description = "Version Number"
  default     = ""
}

variable "tag" {
  description = "Tag"
  default     = "latest"
}

variable "admin_user" {
  description = "Admin credentials for weave scope"
  default     = "admin"
}

variable "admin_password" {
  description = "Admin password for weave scope"
  default     = "admin"
}

variable "manager_volume_size" {
  description = "AWS EC2 manger volume size"
  default     = "8"
}

variable "worker_volume_size" {
  description = "AWS EC2 worker volume size"
  default     = "8"
}

variable "nginx_conf" {
  description = "Nginx conf"
  default     = "../../../../nginx.conf"
}

variable "docker_compose_file" {
  description = "Full path to main docker-stack.yml file"
  default     = "../../../../docker-compose.yml"
}