s/$DNS_SERVER_IP/10.43.0.10/g
s/$DNS_DOMAIN/cluster.local/g
/        - --dns-port=10053/a
s/gcr.io\//\$GCR_IO_REGISTRY\//g
