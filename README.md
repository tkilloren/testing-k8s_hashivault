Testing: Kubernetes Hashicorp Vault integration
===============================================

I wanted a very lightweight platform to test application that use the Kubernetes Vault integration to get secrets.  I don't care if the Vault instance is HA or persists state.  I will set it up to a known state as part of my tests.

To this end, I run Vault in 'dev' mode with a known root token.  This is not secure in any way and is purely to be used as a test fixture that is relatively quick to spin up.


Prerequisites
-------------

Requires the following are installed:
* minishift cli tool
* vault cli tool
* virtualbox


Usage
-----

```sh
./create.sh
```
