#!/bin/bash
set -e -x

while ! kubectl --kubeconfig=/etc/kubernetes/ssl/kubeconfig --namespace=kube-system get ns kube-system >/dev/null 2>&1; do
#  echo "Waiting for kubernetes API to come up..."
  sleep 0.5
done

cat > /tmp/rancher-service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
      name: "io-rancher-system"
      namespace: "kube-system"
EOF

kubectl --kubeconfig=/etc/kubernetes/ssl/kubeconfig create -f /tmp/rancher-service-account.yaml || true 

GCR_IO_REGISTRY=${REGISTRY:-gcr.io}
DOCKER_IO_REGISTRY=${REGISTRY:-docker.io}

for f in $(find /etc/kubernetes/addons -name '*.yaml'); do
  sed -i "s/\$GCR_IO_REGISTRY/$GCR_IO_REGISTRY/g" ${f}
  sed -i "s/\$DOCKER_IO_REGISTRY/$DOCKER_IO_REGISTRY/g" ${f}
  kubectl --kubeconfig=/etc/kubernetes/ssl/kubeconfig --namespace=kube-system replace --force -f ${f}
done

sleep infinity
