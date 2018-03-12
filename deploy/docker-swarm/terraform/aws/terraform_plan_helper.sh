#!/usr/bin/env bash

terraform plan \
    -var-file=config/staging.tfvars \
    -var git_commit='1234' \
    -var git_branch='master' \
    -var version='0.0.1' \
    -var tag=latest \
    -var docker_stack_file=../../../../docker-stack.yml \
    -var nginx_conf=../../../../resources/nginx/nginx.conf \
    -var manager_volume_size=20 \
    -out my.tfplan \
    .
