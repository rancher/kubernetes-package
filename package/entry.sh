#!/bin/bash
set -e -x

if [ "$1" == "kubelet" ]; then
    if [ -d /var/run/nscd ]; then
        mount --bind $(mktemp -d) /var/run/nscd
    fi
fi

/usr/bin/update-rancher-ssl

KUBERNETES_URL=http://169.254.169.250:81

mkdir -p /etc/kubernetes/ssl
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
fi

FQDN=$(hostname --fqdn || hostname)

if [ "$1" == "kubelet" ]; then
    CGROUPDRIVER=$(docker info | grep -i 'cgroup driver' | awk '{print $3}')
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
