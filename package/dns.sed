s/$DNS_SERVER_IP/\$DNS_CLUSTER_IP/g
s/$DNS_DOMAIN/cluster.local/g
/        - --dns-port=10053/a
s/docker.io\//\$GCR_IO_REGISTRY\//g
s/rancher\//\$BASE_IMAGE_NAMESPACE\//g
s/rancher\//\$HELM_IMAGE_NAMESPACE\//g
