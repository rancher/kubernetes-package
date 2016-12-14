FROM debian:jessie

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get -yy -q \
    install \
    iptables \
    ca-certificates \
    file \
    util-linux \
    socat \
    curl \
    ethtool \
    nfs-common \
    jq \
    unzip \
    git \
    glusterfs-client \
    ceph-fs-common \
    ceph-common \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && DEBIAN_FRONTEND=noninteractive apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sLf https://get.docker.com/builds/Linux/x86_64/docker-1.12.3.tgz | tar xvzf - -C /usr/bin --strip-components=1 docker/docker-runc docker/docker \
    && mv /usr/bin/docker-runc /usr/bin/runc \
    && curl -sLf https://get.docker.com/builds/Linux/x86_64/docker-1.11.2.tgz | tar xvzf - -C /usr/bin --strip-components=1 docker/docker-runc \
    && mv /usr/bin/docker-runc /usr/bin/runc-1.11 \
    && mkdir -p /mnt/sda1 \
    && ln -s /var /mnt/sda1/var

ENV CNI v0.3.0-rancher3
RUN mkdir -p /opt/loopback/bin \
    && curl -sfSL https://github.com/rancher/cni/releases/download/${CNI}/cni-${CNI}.tar.gz | \
       tar xvzf - -C /tmp ./loopback \
    && mv /tmp/loopback /opt/loopback/bin

COPY runc-1.10 entry.sh addons-update.sh kubectl kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler /usr/bin/
RUN mkdir -p /etc/kubernetes/addons
COPY kubernetes/cluster/addons/dns /etc/kubernetes/addons/
COPY kubernetes/cluster/addons/dashboard /etc/kubernetes/addons/
COPY kubernetes/cluster/addons/helm /etc/kubernetes/addons/

ENTRYPOINT ["/usr/bin/entry.sh"]
