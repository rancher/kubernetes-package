#!/bin/bash
set -x

function semver_lt() { test "$(printf '%s\n' "$@" | sort -r -V | head -n 1)" != "$1"; }

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

cat <<EOF | kubectl apply -f - || true
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "io-rancher-system"
  namespace: "kube-system"

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: addons-binding
subjects:
- kind: ServiceAccount
  name: io-rancher-system
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF | kubectl apply -f - || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
EOF

DOCKER_IO_REGISTRY=${REGISTRY:-docker.io}
INFLUXDB_RETENTION=${INFLUXDB_RETENTION:-0s}
DNS_REPLICAS=${DNS_REPLICAS:-1}
DNS_CLUSTER_IP=${DNS_CLUSTER_IP:-10.43.0.10}
BASE_IMAGE_NAMESPACE=${BASE_IMAGE_NAMESPACE:-rancher}
ADDONS_LOG_VERBOSITY_LEVEL=${ADDONS_LOG_VERBOSITY_LEVEL:-2}
DASHBOARD_CPU_LIMIT=${DASHBOARD_CPU_LIMIT:-100m}
DASHBOARD_MEMORY_LIMIT=${DASHBOARD_MEMORY_LIMIT:-300Mi}

INFLUXDB_HOST_PATH=${INFLUXDB_HOST_PATH:-}
if [ "$INFLUXDB_HOST_PATH" == "" ]; then
  INFLUXDB_VOLUME="emptyDir: {}"
else
  INFLUXDB_VOLUME="hostPath:\n          path: $INFLUXDB_HOST_PATH"
fi

# Addons Images
# If any of these versions are updated, please also update them in
# addon-templates/README.md
ADDONS_DIR=/etc/kubernetes/addons
DASHBOARD_IMAGE=kubernetes-dashboard-amd64:v1.8.0
KUBEDNS_IMAGE=k8s-dns-kube-dns-amd64:1.14.7
DNSMASQ_IMAGE=k8s-dns-dnsmasq-nanny-amd64:1.14.7
DNS_SIDECAR_IMAGE=k8s-dns-sidecar-amd64:1.14.7
GRAFANA_IMAGE=heapster-grafana-amd64:v4.4.3
HEAPSTER_IMAGE=heapster-amd64:v1.5.0
INFLUXDB_IMAGE=heapster-influxdb-amd64:v1.3.3
TILLER_IMAGE=tiller:v2.7.2

for f in $(find $ADDONS_DIR -name '*.yaml'); do
  sed -i "s|\$DOCKER_IO_REGISTRY|$DOCKER_IO_REGISTRY|g" ${f}
  sed -i "s|\$INFLUXDB_VOLUME|$INFLUXDB_VOLUME|g" ${f}
  sed -i "s|\$INFLUXDB_RETENTION|$INFLUXDB_RETENTION|g" ${f}
  sed -i "s|\$DNS_REPLICAS|$DNS_REPLICAS|g" ${f}
  sed -i "s|\$BASE_IMAGE_NAMESPACE|$BASE_IMAGE_NAMESPACE|g" ${f}
  sed -i "s|\$HELM_IMAGE_NAMESPACE|$HELM_IMAGE_NAMESPACE|g" ${f}
  sed -i "s|\$DNS_CLUSTER_IP|$DNS_CLUSTER_IP|g" ${f}
  sed -i "s|\$ADDONS_LOG_VERBOSITY_LEVEL|$ADDONS_LOG_VERBOSITY_LEVEL|g" ${f}
  sed -i "s|\$DASHBOARD_IMAGE|$DASHBOARD_IMAGE|g" ${f}
  sed -i "s|\$KUBEDNS_IMAGE|$KUBEDNS_IMAGE|g" ${f}
  sed -i "s|\$DNSMASQ_IMAGE|$DNSMASQ_IMAGE|g" ${f}
  sed -i "s|\$DNS_SIDECAR_IMAGE|$DNS_SIDECAR_IMAGE|g" ${f}
  sed -i "s|\$GRAFANA_IMAGE|$GRAFANA_IMAGE|g" ${f}
  sed -i "s|\$HEAPSTER_IMAGE|$HEAPSTER_IMAGE|g" ${f}
  sed -i "s|\$INFLUXDB_IMAGE|$INFLUXDB_IMAGE|g" ${f}
  sed -i "s|\$TILLER_IMAGE|$TILLER_IMAGE|g" ${f}
  sed -i "s|\$DASHBOARD_CPU_LIMIT|$DASHBOARD_CPU_LIMIT|g" ${f}
  sed -i "s|\$DASHBOARD_MEMORY_LIMIT|$DASHBOARD_MEMORY_LIMIT|g" ${f}
done

addons_images=(
    "k8s-app=kubernetes-dashboard,$DASHBOARD_IMAGE,$ADDONS_DIR/dashboard"
    "k8s-app=kube-dns,$KUBEDNS_IMAGE,$ADDONS_DIR/dns"
    "k8s-app=grafana,$GRAFANA_IMAGE,$ADDONS_DIR/heapster/grafana"
    "k8s-app=heapster,$HEAPSTER_IMAGE,$ADDONS_DIR/heapster/heapster"
    "k8s-app=influxdb,$INFLUXDB_IMAGE,$ADDONS_DIR/heapster/influxdb"
    "app=helm,$TILLER_IMAGE,$ADDONS_DIR/helm"
   )

# Check Addon version
for i in "${addons_images[@]}"; do
  current_version=$(kubectl get deployments -n kube-system -o=jsonpath="{..image}" -l "$(echo $i | cut -d"," -f1)" | cut -d" " -f1 | cut -d":" -f2)
  desired_version=$(grep -r "$(echo $i | cut -d"," -f2)" $ADDONS_DIR | cut -d":" -f4)
  set -e
  if [ -z "${current_version}" ]; then
    kubectl --namespace=kube-system replace --force -f $(echo $i | cut -d"," -f3)
  elif [ "${current_version}" == "${desired_version}" ]; then
    kubectl --namespace=kube-system replace --force -f $(echo $i | cut -d"," -f3)
  elif semver_lt ${current_version} ${desired_version}; then
    kubectl --namespace=kube-system replace --force -f $(echo $i | cut -d"," -f3)
  fi
  set +e
done

# Remove orphaned heapster
kubectl -n kube-system delete -l 'k8s-app=heapster' -l 'version=v6' replicaset 2>/dev/null || true

nc -k -l 10240 > /dev/null 2>&1
