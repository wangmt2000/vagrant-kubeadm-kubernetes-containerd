#!/bin/bash
#
# Setup for Node servers

set -euxo pipefail

config_path="/vagrant/configs"

/bin/bash $config_path/join.sh -v

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker
EOF

#拉取镜像
export URL1=registry.cn-hangzhou.aliyuncs.com/ckalab
export URL2=k8s.gcr.io/sig-storage
export IMGN=nfs-subdir-external-provisioner
export IMGV=v4.0.2
sudo ctr -n k8s.io image pull $URL1/$IMGN:$IMGV
sudo ctr -n k8s.io image tag $URL1/$IMGN:$IMGV $URL2/$IMGN:$IMGV