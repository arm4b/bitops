#!/usr/bin/env bash
set -xe


# Logging
export ERROR='\033[0;31m'
export SUCCESS='\033[0;32m'
export WARN='\033[1;33m'
export NC='\033[0m'


###
### Setup
###
echo "making a temporary directory"
export TEMPDIR=$( mktemp -d )
echo "TEMPDIR: $TEMPDIR"

###
### Teardown
###
cleanup () {
  # call all teardown scripts
  /bin/bash $SCRIPTS_DIR/aws/teardown.sh


  echo "cleaning up..."
  local tmpdir=$1
  echo $TEMPDIR

  echo "removing temporary directory: $TEMPDIR"
  rm -rf $TEMPDIR

  printf "BitOps Completed.${NC}"
}
trap "{ cleanup $TEMPDIR; }" EXIT


# Global vars
export PATH=/root/.local/bin:$PATH
export ENVROOT="$TEMPDIR/$ENVIRONMENT"
export BITOPS_DIR="/opt/bitops"
export SCRIPTS_DIR="$BITOPS_DIR/scripts"
export KUBE_CONFIG_FILE="$TEMPDIR/.kube/config"


###
### Global Validation
###
if [ -z "$ENVIRONMENT" ]; then
  printf "${ERROR}environment variable (ENVIRONMENT) not set ${NC}"
  exit 1
fi
if [ -z "$DEBUG" ]; then
  echo "environment variable (DEBUG) not set"
  export DEBUG=0
fi



# put everything in the temp directory
if ! cp -rf /opt/bitops_deployment/. $TEMPDIR; then 
  echo "failed to copy repo to: $TEMPDIR"
else 
  echo "Successfully Copied repo to $TEMPDIR "
fi

if [ -z "$DEFAULT_FOLDER_NAME" ]; then
  DEFAULT_FOLDER_NAME="default"
fi

# ops repo paths
export ROOT_DIR="$TEMPDIR"
export ENVROOT="$ROOT_DIR/$ENVIRONMENT"
export DEFAULT_ENVROOT="$ROOT_DIR/$DEFAULT_FOLDER_NAME"




# Setup bashrc
if [ ! -f !/.bashrc ]; then
  echo "#!/usr/bin/env bash" > ~/.bashrc
  echo "" >> ~/.bashrc
fi
echo "$PATH" >> ~/.bashrc


# Setup cloud provider profile
# TODO: check which cloudprovider
/bin/bash $SCRIPTS_DIR/aws/setup.sh

# Setup kubeconfig from base64
if [ ! -f "$KUBE_CONFIG_FILE" ]; then
  bash $SCRIPTS_DIR/kubectl/kubeconfig_base64_decode.sh
fi



# Run Tests
echo "Running tests"
if [ -n "$TEST" ]; then
  printf "${SUCCESS} all arguments parsed successfully. Exiting... ${NC}" 
  # Todo: Add more tests.

  exit 0
fi



echo "Running deployments"




# run terraform (should be first)
if [ -d "$ENVROOT/terraform" ]; then
  echo "calling terraform/deploy ..."
  bash $SCRIPTS_DIR/terraform/deploy.sh
fi

# run ansible (should be after terraform and before helm)
if [ -d "$ENVROOT/ansible" ]; then
  echo "calling ansible/deploy ..."
  bash $SCRIPTS_DIR/ansible/deploy.sh
fi

# run helm (should be after terraform and ansible)
if [ -d "$ENVROOT/helm" ]; then
  echo "calling helm/deploy ..."
  bash $SCRIPTS_DIR/helm/deploy.sh
fi




