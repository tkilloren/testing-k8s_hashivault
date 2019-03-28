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

export k8s_url=$(minishift console --url)

#===========================
# Install Vault
#===========================
# Add minishift's oc cli to path
eval $(minishift oc-env)

# Login as cluster admin
oc login -u admin -p admin || exit 1

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

VAULT_ADDR="http://$(oc -n vault get route vault --template='{{ .spec.host }}')"
export VAULT_ADDR

while ! curl -s "${VAULT_ADDR}/healthz" | grep -q '{"errors":\[\]}'; do
  echo '  waiting for vault api...'
  sleep 1
done

# Login to vault as root account
vault login root_token

# Enable and configure kubernetes auth plugin
vault auth enable kubernetes

vault_sa_jwt_name=$( \
  oc get sa vault-auth \
     -o jsonpath="{.secrets[*]['name']}" \
  |awk '{for(i=1;i<=NF;i++){if($i ~/-token-/){print $i}}}' \
)

vault_sa_jwt=$( \
  oc get secret ${vault_sa_jwt_name} \
     -o jsonpath="{.data.token}" \
  |base64 --decode; echo \
)

vault_sa_ca=$( \
  oc get secret $vault_sa_jwt_name \
     -o jsonpath="{.data['ca\.crt']}" \
  |base64 --decode; echo \
)


vault write auth/kubernetes/config \
  token_reviewer_jwt="$vault_sa_jwt" \
  kubernetes_host="$k8s_url" \
  kubernetes_ca_cert="$vault_sa_ca"
