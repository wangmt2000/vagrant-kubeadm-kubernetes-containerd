#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)
##############################################################


# 官方考试版本 - CKAD
CKx_URL=https://training.linuxfoundation.cn/certificates/4

KV=$(curl -s $CKx_URL | grep -Eo 软件版本.*v[0-9].[0-9]+ | awk '{print $NF}')

echo -e " The exam is based on Kubernetes: \e[1;34m${KV#v}\e[0;0m"

KV=1.28
# 列出所有小版本
sudo apt-cache madison kubelet | grep ${KV#v}

# 安装 kubelet、kubeadm 和 kubectl 考试版本
sudo apt -y install \
    kubelet=${KV#v}.1-00 \
    kubeadm=${KV#v}.1-00 \
    kubectl=${KV#v}.1-00










# kubeadm init 时，会自动拉取
if ! curl --connect-timeout 2 google.com &>/dev/null; then
    # C. 国内
    RURL=registry.aliyuncs.com/google_containers

    sudo kubeadm config images pull \
        --image-repository $RURL \
        --kubernetes-version ${KV#v}.1

   # sudo sed -i \
    #    -e "/imageRepository/s+:.*+: $RURL+" \
     #   kubeadm-config.yaml
fi
########################################################################









#sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"



sudo kubeadm config print init-defaults > kubeadm-config.yaml




# kubeadm-config.yaml
sudo sed -i \
    -e "/advertiseAddress/s+:.*+: $CONTROL_IP+" \
    -e "/serviceSubnet/s+:.*+: $SERVICE_CIDR+" \
    -e "/name/s+:.*+: $NODENAME+" \
    -e "/clusterName/s+:.*+: ck8s+" \
    -e "/kubernetesVersion/s+:.*+: ${KV#v}.1+" kubeadm-config.yaml
    
#sudo sed -i '/serviceSubnet: =$SERVICE_CIDR/a \  podSubnet: $POD_CIDR' kubeadm-config.yaml
sudo sed -i '/serviceSubnet: 172.17.1.0\/18/a \  podSubnet: 172.16.1.0\/16' kubeadm-config.yaml




sudo sed -i -e "/imageRepository/s+:.*+: $RURL+"   kubeadm-config.yaml

sudo kubeadm init --config kubeadm-config.yaml 
#--apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap


#sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config



#bash-completion
sudo mkdir -p ~/.kube 2>/dev/null

sudo kubectl completion bash \
    > ~/.kube/completion.bash.inc




sudo tee -a ~/.bashrc <<EOF >/dev/null
# Kubectl shell completion
source ~/.kube/completion.bash.inc
EOF

sudo tee -a ~/.bashrc <<EOF >/dev/null
alias k='kubectl'
complete -F __start_kubectl k
EOF

# 立即生效
#sudo source ~/.bashrc









# Save Configs to shared /Vagrant location

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh

kubeadm token create --print-join-command > $config_path/join.sh

# Install Calico Network Plugin

#curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml -O

kubectl apply -f /vagrant/calico.yml

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

sudo kubectl completion bash \
    > /home/vagrant/.kube/completion.bash.inc
sudo cp ~/.bashrc /home/vagrant/.bashrc


# Install Metrics Server

#kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
kubectl apply -f https://nrjqvxfy3a2n.objectstorage.ap-tokyo-1.oci.customer-oci.com/p/RfPsh6y7IvHMjsnKrWG1MsE0i-9gA6tcp0Uf1GiSiNfRNC8otYks42SIViBK1f88/n/nrjqvxfy3a2n/b/forai/o/metrics-server.yaml



chown vagrant:vagrant /home/vagrant/.bashrc
