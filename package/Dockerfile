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

RUN curl -sLf https://get.docker.com/builds/Linux/x86_64/docker-1.12.3.tgz | tar xvzf - -C /usr/bin --strip-components=1 && \
    ln -s /usr/bin/docker-runc /usr/bin/runc

ENV CNI v0.3.0-rancher3
RUN mkdir -p /opt/loopback/bin \
    && curl -sfSL https://github.com/rancher/cni/releases/download/${CNI}/cni-${CNI}.tar.gz | \
       tar xvzf - -C /tmp ./loopback \
    && mv /tmp/loopback /opt/loopback/bin

COPY entry.sh kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler /usr/bin/

ENTRYPOINT ["/usr/bin/entry.sh"]
