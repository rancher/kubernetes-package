s/cluster-proportional-autoscaler-amd64:1.0.0/cluster-proportional-autoscaler-amd64:1.1.1/g
/- --mode=linear/d
s/"min":1/"preventSinglePointFailure":true/g
s/gcr.io\//\$GCR_IO_REGISTRY\//g
