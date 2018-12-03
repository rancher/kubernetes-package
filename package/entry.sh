#!/bin/bash
set -e -x

if [ "$1" == "kubelet" ]; then
    if [ -d /var/run/nscd ]; then
        mount --bind $(mktemp -d) /var/run/nscd
    fi
fi

while ! curl -s -f http://rancher-metadata/2015-12-19/stacks/Kubernetes/services/kubernetes/uuid; do
    echo Waiting for metadata
    sleep 1
done

/usr/bin/update-rancher-ssl

# k8s service certificate
UUID=$(curl -s http://rancher-metadata/2015-12-19/stacks/Kubernetes/services/kubernetes/uuid)
ACTION=$(curl -s -u $CATTLE_ACCESS_KEY:$CATTLE_SECRET_KEY "$CATTLE_URL/services?uuid=$UUID" | jq -r '.data[0].actions.certificate')
KUBERNETES_URL=${KUBERNETES_URL:-https://kubernetes.kubernetes.rancher.internal:6443}

if [ -n "$ACTION" ]; then
    mkdir -p /etc/kubernetes/ssl
    cd /etc/kubernetes/ssl
    curl -s -u $CATTLE_ACCESS_KEY:$CATTLE_SECRET_KEY -X POST $ACTION > certs.zip
    unzip -o certs.zip
    cd $OLDPWD

    TOKEN=$(cat /etc/kubernetes/ssl/key.pem | sha256sum | awk '{print $1}')

    cat > /etc/kubernetes/ssl/kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    certificate-authority: /etc/kubernetes/ssl/ca.pem
    server: "$KUBERNETES_URL"
  name: "Default"
contexts:
- context:
    cluster: "Default"
    user: "Default"
  name: "Default"
current-context: "Default"
users:
- name: "Default"
  user:
    token: "$TOKEN"
EOF
fi
# etcd service certificate
ETCD_UUID=$(curl -s http://rancher-metadata/2015-12-19/stacks/Kubernetes/services/etcd/uuid)
ETCD_ACTION=$(curl -s -u $CATTLE_ACCESS_KEY:$CATTLE_SECRET_KEY "$CATTLE_URL/services?uuid=$ETCD_UUID" | jq -r '.data[0].actions.certificate')

if [ -n "$ETCD_ACTION" ]; then
    mkdir -p /etc/kubernetes/etcd
    cd /etc/kubernetes/etcd
    curl -s -u $CATTLE_ACCESS_KEY:$CATTLE_SECRET_KEY -X POST $ETCD_ACTION > etcd_certs.zip
    unzip -o etcd_certs.zip
    cd $OLDPWD

fi

cat > /etc/kubernetes/authconfig << EOF
clusters:
- name: rancher-kubernetes-auth
  cluster:
    server: http://rancher-kubernetes-auth

users:
- name: rancher-kubernetes

current-context: webhook
contexts:
- context:
    cluster: rancher-kubernetes-auth
    user: rancher-kubernetes
  name: webhook
EOF

# Cloud provider config (if cloudprovider is not rancher)
if ! echo ${@} | grep -q "cloud-provider=rancher"; then
    # Only applicable to kubelet/kube-apiserver/kube-controller-manager
    if [ "$1" == "kubelet" ] || [ "$1" == "kube-apiserver" ] || [ "$1" == "kube-controller-manager" ]; then
        # Check if Azure specific cloud provider config needs to be generated
        if echo ${@} | grep -q "cloud-provider=azure"; then
            AZURE_CLOUD_PROVIDER=1
            source utils.sh
            get_azure_config  > /etc/kubernetes/cloud-provider-config
        fi
        # Check if additional cloud provider config needs to be applied
        if [[ -n "`echo -n "$CLOUD_PROVIDER_CONFIG"`" ]]; then
            # If Azure cloud provider is not configured, write cloud provider config
            if [[ -z ${AZURE_CLOUD_PROVIDER+x} ]]; then
                echo -n "$CLOUD_PROVIDER_CONFIG" > /etc/kubernetes/cloud-provider-config
            # If Azure cloud provider is configured, append to file instead of overwrite
            else
                echo -n "$CLOUD_PROVIDER_CONFIG" >> /etc/kubernetes/cloud-provider-config
            fi
        fi
    fi
fi

# Check for configuration errors
if echo ${@} | grep -q "cloud-config=/etc/kubernetes/cloud-provider-config"; then
    if [ ! -f /etc/kubernetes/cloud-provider-config ]; then
        echo "Configuration error, cloud-provider-config parameter configured but no file present"
        echo "Cloud provider config can only be configured when using 'azure' or 'aws' cloudprovider"
        exit 1
    fi
fi

if [ "$1" == "kubelet" ]; then
    for i in $(DOCKER_API_VERSION=1.22 ./docker info 2>&1  | grep -i 'docker root dir' | cut -f2 -d:) /var/lib/docker /run /var/run; do
        for m in $(tac /proc/mounts | awk '{print $2}' | grep ^${i}/); do
            if [ "$m" != "/var/run/nscd" ] && [ "$m" != "/run/nscd" ]; then
                umount $m || true
            fi
        done
    done
    mount --rbind /host/dev /dev
    mount -o rw,remount /sys/fs/cgroup 2>/dev/null || true
    for i in /sys/fs/cgroup/*; do
        if [ -d $i ]; then
             mkdir -p $i/kubepods
        fi
    done
    if [ -d /sys/fs/cgroup/cpu,cpuacct/ ]
    then
        mkdir -p /sys/fs/cgroup/cpuacct,cpu/
        mount --bind /sys/fs/cgroup/cpu,cpuacct/ /sys/fs/cgroup/cpuacct,cpu/
        mkdir -p /sys/fs/cgroup/net_prio,net_cls/
        mount --bind /sys/fs/cgroup/net_cls,net_prio/ /sys/fs/cgroup/net_prio,net_cls/
    fi
fi

FQDN=$(hostname --fqdn || hostname)

if [ "$1" == "kubelet" ]; then
    CGROUPDRIVER=$(docker info | grep -i 'cgroup driver' | awk '{print $3}')
    # Azure API uses hostnames not FQDNs, if FQDN is used,
    # kubelet wouldn't be able to get node information from the cloud provider.
    if [ "${CLOUD_PROVIDER}" == "azure" ]; then
      FQDN=$(hostname -s)
    fi
    exec "$@" --cgroup-driver=$CGROUPDRIVER --hostname-override ${FQDN}
fi

if [ "$1" == "kube-proxy" ]; then
    exec "$@" --hostname-override ${FQDN}
fi

if [ "$1" == "kube-apiserver" ]; then
    export RANCHER_URL=${CATTLE_URL}
    export RANCHER_ACCESS_KEY=${CATTLE_ACCESS_KEY}
    export RANCHER_SECRET_KEY=${CATTLE_SECRET_KEY}

    LABEL=$(rancher inspect --type=service rancher-kubernetes-agent | jq '.launchConfig.labels."io.rancher.k8s.agent"')
    if [ "${LABEL}" = "null" ]; then
        rancher rm --type=service rancher-kubernetes-agent
    fi

    CONTAINERIP=$(curl -s http://rancher-metadata/2015-12-19/self/container/ips/0)
    exec "$@" "--advertise-address=$CONTAINERIP"
fi

exec "$@"
