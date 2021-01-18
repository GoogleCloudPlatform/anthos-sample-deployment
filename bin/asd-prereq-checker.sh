#!/bin/sh

# This script checks that prerequisites exist to ensure that
# the Anthos Sample Deployment is successfully deployed.
#
# Example usage:
# ./asd-prereq-checker.sh

SERVICE_MANAGEMENT_API=servicemanagement.googleapis.com
COMPUTE_API=compute.googleapis.com
PROJECT_ID=$(gcloud config get-value project 2> /dev/null)
ZONE=$(gcloud config get-value compute/zone 2> /dev/null)
if [[ -z "${ZONE}" ]]; then
  ZONE='us-central1-c'
fi
REGION=$(echo ${ZONE} | awk -F- '{print $1 "-" $2}')

DISABLED_SERVICE_MANAGEMENT_API="{
  'KnownIssueId': 'disabled_service_management_api',
  'Message': 'Service Management API is not enabled. You must enable this API in the current project. https://console.cloud.google.com/apis/api/servicemanagement.googleapis.com/overview?project=$PROJECT_ID '
}"

INVALID_ORG_POLICY_OSLOGIN="{
  'KnownIssueId': 'invalid_org_policy_requireOsLogin',
  'Message': 'An org policy (constraints/compute.requireOsLogin) exists that will prevent this deployment.  Please try this deployment in a project without this org policy.'
}"

INVALID_ORG_POLICY_IPFORWARD="{
  'KnownIssueId': 'invalid_org_policy_vmCanIpForward)',
  'Message': 'An org policy (constraints/compute.vmCanIpForward) exists that will prevent this deployment.  Please try this deployment in a project without this org policy.'
}"

INVALID_ORG_POLICY_TRUSTED_IMAGES="{
  'KnownIssueId': 'invalid_org_policy_trustedImageProjects)',
  'Message': 'An org policy (constraints/compute.trustedImageProjects) exists that will prevent this deployment.  Please try this deployment in a project without this org policy.'
}"

DEPLOYMENT_ALREADY_EXISTS="{
  'KnownIssueId': 'deployment_already_exists',
  'Message': 'An instance of Anthos Sample Deployment already exists. You must delete the previous deployment before performing another deployment.  https://console.cloud.google.com/dm/deployments?project=$PROJECT_ID '
}"

INVALID_PROJECT_ID_COLON="{
  'KnownIssueId': 'invalid_project_id_colon',
  'Message': 'There is a colon in the project id. Please try this deployment in a project without a colon in the project id.'
}"

INVALID_PROJECT_ID_QWIKLABS="{
  'KnownIssueId': 'invalid_project_id_qwiklabs',
  'Message': 'A Qwiklabs project is detected. Anthos Sample Deployment is not designed to run on Qwiklabs environment.'
}"

INSUFFICIENT_REGIONAL_CPUS_QUOTA="{
  'KnownIssueId': 'insufficient_regional_cpus_quota',
  'Message': 'Insufficient regional CPUS quota for 7 more vCPUs in the project.'
}"

INSUFFICIENT_GLOBAL_CPUS_QUOTA="{
  'KnownIssueId': 'insufficient_global_cpus_quota',
  'Message': 'Insufficient CPUS_ALL_REGIONS quota for 7 more vCPUs in the project.'
}"

INSUFFICIENT_NETWORKS_QUOTA="{
  'KnownIssueId': 'insufficient_networks_quota',
  'Message': 'Insufficient NETWORKS quota for 1 more network in the project.'
}"

INSUFFICIENT_FIREWALLS_QUOTA="{
  'KnownIssueId': 'insufficient_firewalls_quota',
  'Message': 'Insufficient FIREWALLS quota for 2 more firewalls in the project.'
}"

function check_iam_policy {
  # iam.serviceAccounts.create and iam.serviceAccounts.setIamPolicy are the
  # 2 required permissions for the user to be able to create
  # the service account.  Sufficient to check them by IAM roles.
  account=$(gcloud config list account --format "value(core.account)")
  result=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:$account")
  if [[ "$result" == *"roles/owner"* || "$result" == *"roles/editor"* || "$result" == *"roles/iam.serviceAccountAdmin"* ]]; then
    echo "PASS: User has permission to create service account with the required IAM policies."
  else
    echo
    echo "WARNING: Unable to verify if you have the necessary permission to create a service account with the required IAM policy. Please verify manually that you have iam.serviceAccounts.create and iam.serviceAccounts.setIamPolicy permissions, and then proceed with deployment.  https://console.cloud.google.com/iam-admin/iam?project=$PROJECT_ID  You can also disregard this warning, if you will be providing your own pre-existing service account."
    echo
  fi
}

function check_org_policy_is_valid {
  if ! gcloud beta resource-manager org-policies list --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "WARNING: Unable to verify if the project has any Organization Policies that will prevent the deployment."
    return
  fi

  result=$(gcloud beta resource-manager org-policies describe compute.requireOsLogin --project=$PROJECT_ID --effective)
  if [[ "$result" == *"enforced: true"* ]]; then
    echo
    echo $INVALID_ORG_POLICY_OSLOGIN
    echo
    exit 1
  fi

  result=$(gcloud beta resource-manager org-policies describe compute.vmCanIpForward --project=$PROJECT_ID --effective)
  if [[ "$result" == *"DENY"* ]]; then
    echo
    echo $INVALID_ORG_POLICY_IPFORWARD
    echo
    exit 1
  fi

  result=$(gcloud beta resource-manager org-policies describe compute.trustedImageProjects --project=$PROJECT_ID --effective)
  if [[ "$result" == *"DENY"* ]]; then
    echo
    echo $INVALID_ORG_POLICY_TRUSTED_IMAGES
    echo
    exit 1
  fi

  echo "PASS: Org Policy will allow this deployment."
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
  fi

  echo "PASS: Anthos Sample Deployment does not already exist."
}

function check_project_id_is_valid {
  if [[ "$PROJECT_ID" == *":"* ]]; then
    echo
    echo $INVALID_PROJECT_ID_COLON
    echo
    exit 1
  elif [[ "$PROJECT_ID" =~ ^qwiklabs-gcp-.{2}-.{12}$ ]]; then
    echo
    echo $INVALID_PROJECT_ID_QWIKLABS
    echo
    exit 1
  fi
  echo "PASS: Project ID is valid."
}


function check_quota_is_sufficient {
  api=$(gcloud services list --format=json --filter=name:$COMPUTE_API)
  if [[ "$api" != *"$COMPUTE_API"* ]]; then
    echo "WARNING: Unable to verify compute quota because $COMPUTE_API in project $PROJECT_ID is not enabled. Enable this API in the current project at https://console.cloud.google.com/apis/api/compute.googleapis.com/overview?project=$PROJECT_ID and run this script again."
    return
  fi

  quota=$(gcloud compute regions describe ${REGION} --flatten quotas --format="csv(quotas.metric,quotas.limit,quotas.usage)"|egrep '^CPUS,')
  limit=$(echo $quota | awk -F, '{print $2}' | awk -F. '{print $1}' )
  usage=$(echo $quota | awk -F, '{print $3}' | awk -F. '{print $1}' )
  remain=$(( limit - usage ))
  if (( remain < 7 )); then
    echo $INSUFFICIENT_REGIONAL_CPUS_QUOTA
    exit 1
  fi

  if gcloud compute project-info describe --flatten quotas --format="csv(quotas.metric,quotas.limit,quotas.usage)"|egrep '^CPUS_ALL_REGIONS' > /dev/null; then
    quota=$(gcloud compute project-info describe --flatten quotas --format="csv(quotas.metric,quotas.limit,quotas.usage)"|egrep '^CPUS_ALL_REGIONS,')
    limit=$(echo $quota | awk -F, '{print $2}' | awk -F. '{print $1}' )
    usage=$(echo $quota | awk -F, '{print $3}' | awk -F. '{print $1}' )
    remain=$(( limit - usage ))
    if (( remain < 7 )); then
      echo $INSUFFICIENT_GLOBAL_CPUS_QUOTA
      exit 1
    fi
  fi

  quota=$(gcloud compute project-info describe --flatten quotas --format="csv(quotas.metric,quotas.limit,quotas.usage)"|egrep '^NETWORKS,')
  limit=$(echo $quota | awk -F, '{print $2}' | awk -F. '{print $1}' )
  usage=$(echo $quota | awk -F, '{print $3}' | awk -F. '{print $1}' )
  remain=$(( limit - usage ))
  if (( remain < 1 )); then
    echo $INSUFFICIENT_NETWORKS_QUOTA
    exit 1
  fi

  quota=$(gcloud compute project-info describe --flatten quotas --format="csv(quotas.metric,quotas.limit,quotas.usage)"|egrep '^FIREWALLS')
  limit=$(echo $quota | awk -F, '{print $2}' | awk -F. '{print $1}' )
  usage=$(echo $quota | awk -F, '{print $3}' | awk -F. '{print $1}' )
  remain=$(( limit - usage ))
  if (( remain < 2 )); then
    echo $INSUFFICIENT_FIREWALLS_QUOTA
    exit 1
  fi

  echo "PASS: Project has sufficient quota to support this deployment."
}

function usage {
  echo "Project ID must be set: gcloud config set project [PROJECT_ID]"
  echo "Optionally, set deployment zone: gcloud config set compute/zone [ZONE]"
  echo "Then rerun ${0##*/}"
  exit 1
}

if [[ -z "${PROJECT_ID}" ]]; then
  usage >&2
fi

echo "Checking project ${PROJECT_ID}, region ${REGION}, zone ${ZONE}"
echo
check_iam_policy
check_org_policy_is_valid
check_service_management_api_is_enabled
check_deployment_does_not_exist
check_project_id_is_valid
check_quota_is_sufficient
