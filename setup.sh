#!/bin/bash

# Install Docker
yum update -y
yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Set AWS region and account ID
export AWS_REGION=$(aws configure get region)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Create .env file from SSM parameters
for param in POSTGRES_USER POSTGRES_DB POSTGRES_PASSWORD POSTGRES_PORT COSTA_API_PORT; do
   aws ssm get-parameter --name "/app/${param}" --with-decryption --query Parameter.Value --output text >> .env
done

# Add AWS variables to .env
echo "AWS_REGION=${AWS_REGION}" >> .env
echo "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}" >> .env

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
 database:
   image: postgres:17.2-alpine
   environment:
     - POSTGRES_USER=${POSTGRES_USER}
     - POSTGRES_DB=${POSTGRES_DB}
     - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
   ports:
     - "${POSTGRES_PORT}:${POSTGRES_PORT}"
   volumes:
     - db:/var/lib/postgresql/data
   healthcheck:
     test: ["CMD", "pg_isready", "-U", "${POSTGRES_USER}", "-d", "${POSTGRES_DB}"]
     interval: 5s
     retries: 5

 liquibase:
   image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/liquibase:latest
   volumes:
     - "./scripts:/changelogs"
   command:
     - --url=jdbc:postgresql://database:5432/${POSTGRES_DB}
     - --username=${POSTGRES_USER}
     - --password=${POSTGRES_PASSWORD}
     - --changeLogFile=master-changelog.xml
     - --searchPath=/changelogs
     - update
   depends_on:
     database:
       condition: service_healthy

 api:
   image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/api:latest
   env_file:
     - .env
   ports:
     - "${COSTA_API_PORT}:${COSTA_API_PORT}"
   depends_on:
     database:
       condition: service_healthy
     liquibase:
       condition: service_completed_successfully

volumes:
 db:
EOF

# Start services
docker-compose up -d