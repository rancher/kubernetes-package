#!/bin/bash
set -e -x

if [ ${DISABLE_ADDONS} == "true" ]; then
    echo "addons have been disabled"
    sleep infinity
fi

export KUBECONFIG=/etc/kubernetes/ssl/kubeconfig

while ! kubectl --namespace=kube-system get ns kube-system >/dev/null 2>&1; do
#  echo "Waiting for kubernetes API to come up..."
  sleep 2
done

# Remove old influx
kubectl delete --namespace kube-system deployment influxdb-grafana 2>/dev/null || true

cat > /tmp/rancher-service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
      name: "io-rancher-system"
      namespace: "kube-system"
EOF

kubectl create -f /tmp/rancher-service-account.yaml || true 

GCR_IO_REGISTRY=${REGISTRY:-gcr.io}
DOCKER_IO_REGISTRY=${REGISTRY:-docker.io}
INFLUXDB_RETENTION=${INFLUXDB_RETENTION:-0s}


INFLUXDB_HOST_PATH=${INFLUXDB_HOST_PATH:-}
if [ "$INFLUXDB_HOST_PATH" == "" ]; then
  INFLUXDB_VOLUME="emptyDir: {}"
else
  INFLUXDB_VOLUME="hostPath:\n          path: $INFLUXDB_HOST_PATH"
fi

for f in $(find /etc/kubernetes/addons -name '*.yaml'); do
  sed -i "s|\$GCR_IO_REGISTRY|$GCR_IO_REGISTRY|g" ${f}
  sed -i "s|\$DOCKER_IO_REGISTRY|$DOCKER_IO_REGISTRY|g" ${f}
  sed -i "s|\$INFLUXDB_VOLUME|$INFLUXDB_VOLUME|g" ${f}
  sed -i "s|\$INFLUXDB_RETENTION|$INFLUXDB_RETENTION|g" ${f}
  kubectl --namespace=kube-system replace --force -f ${f}
done

# Remove orphaned heapster
kubectl -n kube-system delete -l 'k8s-app=heapster' -l 'version=v6' replicaset 2>/dev/null || true

sleep infinity
