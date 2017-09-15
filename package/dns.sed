s/$DNS_SERVER_IP/\$DNS_CLUSTER_IP/g
s/$DNS_DOMAIN/cluster.local/g
/        - --dns-port=10053/a
s/gcr.io\//\$GCR_IO_REGISTRY\//g
s/google_containers\//\$BASE_IMAGE_NAMESPACE\//g
s/kubernetes-helm\//\$HELM_IMAGE_NAMESPACE\//g
