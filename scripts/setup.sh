#!/bin/bash
{
    # Install docker and helper
    yum update -y
    sudo yum install -y docker amazon-ecr-credential-helper
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user

    # Configure docker creds and env vars for both users
    mkdir -p /home/ec2-user/.docker
    echo '{"credsStore": "ecr-login"}' > /home/ec2-user/.docker/config.json
    chmod 600 /home/ec2-user/.docker/config.json
    chown -R ec2-user:ec2-user /home/ec2-user/.docker

    sudo mkdir -p /root/.docker
    sudo cp /home/ec2-user/.docker/config.json /root/.docker/
    sudo chmod 600 /root/.docker/config.json

    echo 'export DOCKER_CONFIG=/home/ec2-user/.docker' >> /home/ec2-user/.bashrc
    sudo bash -c 'echo "export DOCKER_CONFIG=/home/ec2-user/.docker" >> /root/.bashrc'
    echo 'export AWS_REGION=us-west-2' | sudo tee -a /etc/environment

    # Install Docker Compose
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    source /home/ec2-user/.bashrc

    echo "Restarting docker..."
    sudo systemctl restart docker
    echo "Restarted docker"
} > /home/ec2-user/user-data.log 2>&1