s/$DNS_SERVER_IP/10.43.0.10/g
s/$DNS_REPLICAS/2/g
s/$DNS_DOMAIN/cluster.local/g
/        - --dns-port=10053/a \
        - --kube-master-url=http://kubernetes.kubernetes:80
