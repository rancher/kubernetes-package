s/$DNS_SERVER_IP/10.43.0.10/g
s/$DNS_DOMAIN/cluster.local/g
/        - --dns-port=10053/a \
        - --kube-master-url=http://kubernetes.kubernetes:80
s/gcr.io\//\$GCR_IO_REGISTRY\//g
s/kind: Deployment/kind: DaemonSet/g
s/  strategy:/  updateStrategy:\
    type: RollingUpdate/
/      maxSurge:/d
s/      maxUnavailable: 0/      maxUnavailable: 1/g
