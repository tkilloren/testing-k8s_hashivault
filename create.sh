#!/bin/sh

OPENSHIFT_VERSION=v3.10.0

#===========================
# Create Container Platform
#===========================

# Create a Minishift Cluster
minishift start \
  --v 5 \
  --memory 8GB \
  --openshift-version $OPENSHIFT_VERSION \
  --vm-driver virtualbox

# Turn on cluster admin user (admin:admin)
# See https://github.com/minishift/minishift/issues/2107
minishift addon apply admin-user


#===========================
# Install Vault
#===========================
# Add minishift's oc cli to path
eval $(minishift oc-env)

# Login as a cluster admin
oc login -u admin -p admin

# Create a namespace for HashiVault
oc new-project vault

# Need to add IPC_LOCK capability to container
oc adm policy add-scc-to-user privileged -z default

# Build the Kubernetes objects to run Vault in server mode
oc apply -f openshift/vault.yaml


#===========================
# Integrate Vault
#===========================

# You need a ServicAccount with 'auth-delgator' privs for Vault to talk to.
oc create sa vault-auth
oc adm policy add-cluster-role-to-user system:auth-delegator system:serviceaccount:vault-controller:vault-auth


# Login to vault as root account
VAULT_ADDR="http://$(oc -n vault get route vault --template='{{ .spec.host }}')"
export VAULT_ADDR
vault login root_token

# Enable and configure kubernetes auth plugin
vault auth enable kubernetes

export VAULT_SA_JWT_NAME=$(oc get sa vault-auth -o jsonpath="{.secrets[*]['name']}"\
   |awk '$1 ~/-token-/ {print $1}')

export VAULT_SA_JWT=$(oc get secret $VAULT_SA_JWT_NAME -o jsonpath="{.data.token}"\
   |base64 --decode; echo)

export VAULT_SA_CA=$(oc get secret $VAULT_SA_JWT_NAME \
                     -o jsonpath="{.data['ca\.crt']}" \
                    |base64 --decode; echo)

export K8_URL=$(minishift console --url)

vault write auth/kubernetes/config \
  token_reviewer_jwt="$VAULT_SA_JWT" \
  kubernetes_host="$K8_URL" \
  kubernetes_ca_cert="$VAULT_SA_CA"
