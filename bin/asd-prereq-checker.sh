#!/bin/sh

# This script checks that prerequisites exist to ensure that
# the Anthos Sample Deployment is successfully deployed.
#
# Example usage:
# ./asd-prereq-checker.sh --network foo_network

NETWORK=""
SERVICE_MANAGEMENT_API=servicemanagement.googleapis.com

PROJECT_ID=$(gcloud config get-value project)

DISABLED_SERVICE_MANAGEMENT_API="{
  'KnownIssueId': 'disabled_service_management_api',
  'Message': 'Service Management API is not enabled. You must enable this API in the current project. https://console.cloud.google.com/apis/api/servicemanagement.googleapis.com/overview?project=$PROJECT_ID '
}"

DEPLOYMENT_ALREADY_EXISTS="{
  'KnownIssueId': 'deployment_already_exists',
  'Message': 'An instance of Anthos Sample Deployment already exists. You must delete the previous deployment before performing another deployment.  https://console.cloud.google.com/dm/deployments?project=$PROJECT_ID '
}"

INVALID_PROJECT_ID="{
  'KnownIssueId': 'invalid_project_id',
  'Message': 'There is a colon in the project id. Please try this deployment in a project without a colon in the project id.'
}"

INVALID_NETWORK_LEGACY="{
  'KnownIssueId': 'invalid_network_legacy',
  'Message': 'Legacy network is found.  Please try this deployment in a non-legacy network.  https://console.cloud.google.com/networking/networks/list?project=$PROJECT_ID '
}"

INVALID_NETWORK_NOT_FOUND="{
  'KnownIssueId': 'invalid_network_not_found',
  'Message': 'Specified network is not found.  Please double-check and try again. '
}"

INVALID_GATEWAY="{
  'KnownIssueId': 'invalid_gateway',
  'Message': 'No internet gateway is found for this network. Please add a 0.0.0.0/0 route to the internet.  https://console.cloud.google.com/networking/routes/list?project=$PROJECT_ID '
}"


function parse_flags() {
  while test $# -gt 0; do
    case "$1" in
      -n|--network)
        NETWORK="$2"
        shift
        shift
        ;;
      *)
        shift  # Remove generic argument from processing
        ;;
    esac
  done

  if [[ -z "$NETWORK" ]]; then
    echo
    echo "Please use the --network flag to specify the network that Anthos Sample Deployment will use."
    echo
    exit 1
  fi
}

function check_iam_policy {
  # iam.serviceAccounts.create and iam.serviceAccounts.setIamPolicy are the
  # 2 permissions that need to be in place.  Sufficient to check them by
  # IAM roles.
  # the list default is unlimited, no paging
  result=$(gcloud iam roles list --format=json | grep "name")
  if [[ "$result" == *"roles/owner"* || "$result" == *"roles/editor"* || "$result" == *"roles/iam.serviceAccountAdmin"* ]]; then
    echo "PASS: User has permission to create service account with the required IAM policies."
  else
    echo
    echo "WARNING: Unable to verify if you have the necessary permission to create a service account with the required IAM policy. Please verify manually that you have iam.serviceAccounts.create and iam.serviceAccounts.setIamPolicy permissions, and then proceed with deployment.  https://console.cloud.google.com/iam-admin/iam?project=$PROJECT_ID  You can also disregard this warning, if you will be providing your own pre-existing service account."
    echo
  fi
}

function check_service_management_api_is_enabled {
  # Getting json output removes an output of `Listed 0 items` that
  # goes to the terminal.
  result=$(gcloud services list --format=json --filter=name:$SERVICE_MANAGEMENT_API)
  if [[ "$result" != *"$SERVICE_MANAGEMENT_API"* ]]; then
    echo
    echo $DISABLED_SERVICE_MANAGEMENT_API
    echo
    exit 1
  else
    echo "PASS: Service Management API is enabled."
  fi
}

function check_deployment_does_not_exist {
  result=$(gcloud container clusters list --format=json --filter=name:anthos-sample-cluster1)
  if [[ "$result" == *"anthos-sample-cluster"* ]]; then
    echo
    echo $DEPLOYMENT_ALREADY_EXISTS
    echo
    exit 1
  else
    echo "PASS: Anthos Sample Deployment does not already exist."
  fi
}

function check_project_id_is_valid {
  if [[ "$PROJECT_ID" == *":"* ]]; then
    echo
    echo $INVALID_PROJECT_ID
    echo
    exit 1
  else
    echo "PASS: Project ID is valid, does not contain colon."
  fi
}

function check_network_is_valid {
  result=$(gcloud compute networks list --format=json --filter=name:$NETWORK)
  if [[ "$result" == "[]" ]]; then
    echo
    echo $INVALID_NETWORK_NOT_FOUND
    echo
    exit 1
  elif [[ "$result" == *"legacy"* ]]; then
    echo
    echo $INVALID_NETWORK_LEGACY
    echo
    exit 1
  else
    echo "PASS: Network is valid."
  fi
}

function check_internet_gateway_exists {
  result=$(gcloud compute routes list --format=json --filter=network:$NETWORK)
  if [[ "$result" != *"0.0.0.0/0"* ]]; then
    echo
    echo $INVALID_GATEWAY
    echo
    exit 1
  else
    echo "PASS: Internet gateway exists."
  fi
}

parse_flags "$@"
check_iam_policy
check_service_management_api_is_enabled
check_deployment_does_not_exist
check_project_id_is_valid
check_network_is_valid
check_internet_gateway_exists
