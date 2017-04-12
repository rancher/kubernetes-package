# Building and Releasing Kubernetes

## Projects that build with dapper

1) Kubernetes-agent: https://github.com/rancher/kubernetes-agent

results in rancher/kubernetes-agent:tag image

2) Ingress controller: https://github.com/rancher/lb-controller

results in rancher/lb-service-rancher:tag image

3) Kubectld: https://github.com/rancher/kubectld

results in rancher/kubectld:tag image


## Building kubernetes

Kubernetes image used for controller/k8s/kubelet/proxy/scheduler services. 
Source: https://github.com/rancher/kubernetes
Packaging: https://github.com/rancher/kubernetes-package

If only packaging changes are required:

1) Make changes in kubernetes-package.
2) Create and push tag
3) Run make, it should generate the image with the new tag.

If kubernetes base got changed - either sync with upstream was performed, or some bug fix went in, do this:

### https://github.com/rancher/kubernetes

1) Build k8s binaries using  rancher-k8s-build/build.sh under .
2) Create and push tag
3) Upload binaries built on step 1 to the release

### https://github.com/rancher/kubernetes-package

1) Point dockerfile.dapper to a new binary:

https://github.com/rancher/kubernetes-package/blob/master/Dockerfile.dapper#L8

2) Commit the changes, create and push tag
3) Run make to generate a new image.

### Syncing rancher kubernetes with upstream

1) Add remote git@github.com:kubernetes/kubernetes.git, lets call it upstream. Rancher is origin, git@github.com:rancher/kubernetes.git
2) Lets say you need to update kubernetes rancher v1.5.1-rancher with k8s upstream v1.5.2. For that:

git checkout -b v1.5.2-rancher v1.5.1-rancher
git rebase -i v1.5.2
git push origin v1.5.2-rancher

### K8s template in rancher catalog

https://github.com/rancher/rancher-catalog/tree/master/infra-templates/k8s
