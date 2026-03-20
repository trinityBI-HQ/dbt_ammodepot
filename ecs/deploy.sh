#!/bin/bash
set -euo pipefail

# Deploy dbt-core Docker image to ECR
# Usage: ./scripts/deploy-ecs.sh

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ammodepot/dbt"
IMAGE_TAG=$(git rev-parse --short HEAD)

echo "=== Deploying dbt image ==="
echo "Account:  ${AWS_ACCOUNT_ID}"
echo "Repo:     ${ECR_REPO}"
echo "Tag:      ${IMAGE_TAG}"
echo ""

# Authenticate to ECR
echo "Authenticating to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_REPO}"

# Build image
echo "Building image..."
docker build -t "${ECR_REPO}:${IMAGE_TAG}" \
             -t "${ECR_REPO}:latest" \
             -f ecs/Dockerfile .

# Push both tags
echo "Pushing ${IMAGE_TAG}..."
docker push "${ECR_REPO}:${IMAGE_TAG}"
echo "Pushing latest..."
docker push "${ECR_REPO}:latest"

echo ""
echo "=== Done ==="
echo "Image: ${ECR_REPO}:${IMAGE_TAG}"
echo "Next scheduled run will use the new image automatically."
