#!/usr/bin/env bash
set -euo pipefail

# Usage:
# ./down.sh <your-name>
#
# Example:
# ./down.sh ahsan-4


NAME="${1:-}"

if [ -z "$NAME" ]; then
  echo "Usage: ./down.sh <your-name>"
  echo "Example: ./down.sh ahsan-4"
  exit 1
fi


REGION="${AWS_REGION:-us-east-1}"
VPC_NAME="vpc-${NAME}"
CLUSTER_NAME="eks-${NAME}"


echo "======================================"
echo " EKS Cluster Cleanup"
echo " Cluster : ${CLUSTER_NAME}"
echo " VPC     : ${VPC_NAME}"
echo " Region  : ${REGION}"
echo "======================================"



# -------------------------------------------------------
# Safety check: Kubernetes context
# -------------------------------------------------------

echo ""
echo ">> Current kubectl cluster:"

CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "NONE")

echo "   ${CURRENT_CONTEXT}"

echo ""
echo ">> Expected cluster:"
echo "   ${CLUSTER_NAME}"

read -p "Continue deleting this cluster? Type YES: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Cancelled."
    exit 1
fi



# -------------------------------------------------------
# Find VPC
# -------------------------------------------------------

echo ""
echo ">> Finding VPC..."

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${VPC_NAME}" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "${REGION}")


if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo "No VPC found for ${VPC_NAME}"
    echo "Running Terraform destroy directly..."
else
    echo "Found VPC:"
    echo "   ${VPC_ID}"
fi



# -------------------------------------------------------
# Delete Kubernetes LoadBalancer services
# -------------------------------------------------------

echo ""
echo ">> Removing Kubernetes LoadBalancer services..."


kubectl get svc -A \
  -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
  2>/dev/null \
  | while read namespace service; do

        if [ -n "${service}" ]; then
            echo "Deleting service:"
            echo "   ${namespace}/${service}"

            kubectl delete svc "${service}" \
                -n "${namespace}" \
                --ignore-not-found

        fi

    done || true



echo ""
echo ">> Waiting for AWS Load Balancers cleanup..."
sleep 60



# -------------------------------------------------------
# Delete VPC endpoints
# -------------------------------------------------------

if [ -n "${VPC_ID:-}" ] && [ "${VPC_ID}" != "None" ]; then

    echo ""
    echo ">> Checking VPC endpoints..."

    VPCE_IDS=$(aws ec2 describe-vpc-endpoints \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query "VpcEndpoints[*].VpcEndpointId" \
        --output text \
        --region "${REGION}")


    if [ -n "${VPCE_IDS}" ]; then

        echo "Deleting VPC endpoints:"
        echo "${VPCE_IDS}"


        aws ec2 delete-vpc-endpoints \
            --vpc-endpoint-ids ${VPCE_IDS} \
            --region "${REGION}" || true


        echo "Waiting for endpoint deletion..."
        sleep 30

    else
        echo "No VPC endpoints found."
    fi



    # -------------------------------------------------------
    # Delete leftover ENIs
    # -------------------------------------------------------

    echo ""
    echo ">> Checking remaining ENIs..."


    ENIS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query "NetworkInterfaces[*].NetworkInterfaceId" \
        --output text \
        --region "${REGION}")


    if [ -n "${ENIS}" ]; then

        echo "Found ENIs:"
        echo "${ENIS}"


        for ENI in ${ENIS}; do

            echo "Deleting ENI:"
            echo "   ${ENI}"

            aws ec2 delete-network-interface \
                --network-interface-id "${ENI}" \
                --region "${REGION}" || true

        done


        echo "Waiting for ENI cleanup..."
        sleep 30

    else
        echo "No ENIs found."
    fi

fi



# -------------------------------------------------------
# Terraform destroy
# -------------------------------------------------------

echo ""
echo ">> Running Terraform destroy..."


terraform destroy \
    -auto-approve \
    -var="student_name=${NAME}"



echo ""
echo "======================================"
echo " Cleanup completed!"
echo " ${CLUSTER_NAME} has been removed."
echo "======================================"