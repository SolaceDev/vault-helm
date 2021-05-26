# Logrotate
Cusomized logrotate to run as a sidecar container running as user vault (running as root might expose vault secrets on the node). Logrotate is not `logrotate.conf` file needs to be mounted into this container.

If you choose to change the defualt .Values.server.uid and .Values.server.gid for Vault the UID and GID environment variables in Dockerfile would have be updated accordingly. Then image would have to be rebuilt and pushed to GCR, independently.

## Building/Pushing image GCR
* Build the image using make 
```
make build
```
* Tag and Push image to GCR

```
docker tag maas-vault-logrotate:latest gcr.io/gcp-project>/maas-vault-logrotate
docker push gcr.io/<gcp-project>/maas-vault-logrotate
```  
