#!/bin/bash
set -e -x

while ! kubectl --kubeconfig=/etc/kubernetes/ssl/kubeconfig --namespace=kube-system get ns kube-system >/dev/null 2>&1; do
#  echo "Waiting for kubernetes API to come up..."
  sleep 2
done


for f in $(find /etc/kubernetes/addons -name '*.yaml'); do
  echo "---" && cat $f
done | kubectl --kubeconfig=/etc/kubernetes/ssl/kubeconfig --namespace=kube-system replace --force -f -
