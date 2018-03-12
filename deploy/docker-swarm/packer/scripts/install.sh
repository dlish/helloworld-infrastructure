#!/bin/bash

# Allow toggling components to install and update based off flags
updatedocker=1
updatedockercompose=1

dockercomposeversion="1.19.0"

echo ""
echo "Updating Docker($updatedocker)"
echo "Updating Docker Compose($updatedockercompose)"

echo ""
echo "Starting Install"
echo ""

# add docker group and add ubuntu to it
groupadd docker
usermod -aG docker $(whoami)
usermod -aG docker ubuntu

# Install latest Docker Engine
if [ $updatedocker -eq 1 ]; then
  echo ""
  echo "Installing Docker engine"
  echo ""
  apt-get update \
    && apt-get install -y apt-transport-https ca-certificates curl software-properties-common \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce \
    && apt-get clean && apt-get purge \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
    && service docker start \
    && systemctl enable docker
  docker run hello-world
  docker version
  echo ""
  echo "Done Installing Docker engine"
  echo ""
fi

# Now install Docker-Compose: https://github.com/docker/compose/releases/
if [ $updatedockercompose -eq 1 ]; then
  echo ""
  echo "Installing Docker Compose version: $dockercomposeversion"
  echo ""
  curl -L https://github.com/docker/compose/releases/download/${dockercomposeversion}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  docker-compose version
  echo ""
  echo "Done Installing Docker Compose version: $dockercomposeversion"
  echo ""
fi

echo ""
echo "Installing Docker Compose version: $dockercomposeversion"
echo ""
curl -L https://github.com/docker/compose/releases/download/${dockercomposeversion}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose version
echo ""
echo "Done Installing Docker Compose version: $dockercomposeversion"
echo ""

exit 0
