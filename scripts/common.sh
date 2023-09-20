#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

# Variable Declaration

# DNS Setting
if [ ! -d /etc/systemd/resolved.conf.d ]; then
	sudo mkdir /etc/systemd/resolved.conf.d/
fi
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo systemctl restart systemd-resolved

# disable swap
sudo swapoff -a

# keeps the swap off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y
# Install CRI-O Runtime

VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+')"



# Which services should be restarted?
NFILE=/etc/needrestart/needrestart.conf

sudo sed -i \
   -e '/nrconf{restart}/{s+i+a+;s+#++}'  \
   $NFILE

grep nrconf{restart} $NFILE

# 手动更新
sudo apt -y update

## 安装
# -  远程, ssh 免交互, 编辑文件, storageClass
# -  Tab 自动补全, nc, ping
# -  vm-tools
sudo apt -y install \
   openssh-server sshpass vim nfs-common \
   bash-completion netcat-openbsd iputils-ping \
   open-vm-tools

#设置root密码
ROOT_PASS=ubuntu

(echo $ROOT_PASS; echo $ROOT_PASS) \
   | sudo passwd root

echo PermitRootLogin yes \
   | sudo tee -a /etc/ssh/sshd_config

sudo systemctl restart sshd

## 1. Bridge

sudo apt -y install bridge-utils


# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/br.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
EOF

sudo sysctl --system

# 立即生效
sudo sysctl -p /etc/sysctl.d/99-kubernetes.conf

sudo sysctl -a | grep 'ip_forward '



## 创建镜像仓库文件
AFILE=/etc/apt/sources.list.d/docker.list

if ! curl --connect-timeout 2 google.com &>/dev/null; then
    # C. 国内
    AURL=https://mirror.nju.edu.cn/docker-ce
else
    # A. 国外
    AURL=https://download.docker.com
fi

sudo tee $AFILE >/dev/null <<EOF
deb $AURL/linux/ubuntu $(lsb_release -cs) stable
EOF

cat $AFILE

# 导入公钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo apt-key add -

# W: Key is stored in legacy trusted.gpg keyring
sudo cp /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d

# 更新索引
sudo apt-get update




# 安装 containerd
sudo apt-get install containerd.io

# 生成默认配置文件
containerd config default \
    | sudo tee /etc/containerd/config.toml >/dev/null

## 修改配置文件
#   "alpine"
#   376ms  https://docker.nju.edu.cn
#   623ms  http://hub-mirror.c.163.com 
#   10.97s https://docker.mirrors.ustc.edu.cn
sudo sed -i \
    -e '/SystemdCgroup/s+false+true+' \
    /etc/containerd/config.toml

if ! curl --connect-timeout 2 google.com &>/dev/null; then
    # C. 国内
    REISTRY_OLD=registry.k8s.io
    REGISTRY_NEW=registry.aliyuncs.com/google_containers
    M1='[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]'
    M2='endpoint = ["https://docker.nju.edu.cn"]'

    sudo sed -i \
        -e "/sandbox_image/s+$REISTRY_OLD+$REGISTRY_NEW+" \
        -e "/registry.mirrors/a\        $M1" \
        -e "/registry.mirrors/a\          $M2" \
        /etc/containerd/config.toml 
fi


sudo systemctl daemon-reload
sudo systemctl restart containerd

## 下载 crictl 压缩包
if ! curl --connect-timeout 2 google.com &>/dev/null; then
    # C. 国内
    CURL=http://k8s.ruitong.cn:8080/K8s
else
    # A. 国外
    CURL=https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.28.0
fi

TFILE=crictl-v1.28.0-linux-amd64.tar.gz

curl -LO# $CURL/$TFILE

# 解压 crictl
tar -xf $TFILE

# 安装 crictl 命令
sudo cp crictl /usr/bin/

# 创建 crictl 配置文件
sudo tee /etc/crictl.yaml <<EOF >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: true
EOF

# 注销重新登陆后，生效 
sudo usermod -aG root $USER




# 更新 apt 包索引并安装使用 Kubernetes apt 仓库所需要的包
sudo apt -y install apt-transport-https ca-certificates curl

## 添加 Kubernetes apt 仓库
sudo mkdir -p /etc/apt/keyrings &>/dev/null

KFILE=/etc/apt/keyrings/kubernetes-archive-keyring.gpg

if ! curl --connect-timeout 2 google.com &>/dev/null; then
    # C. 国内
    KURL=http://k8s.ruitong.cn:8080/K8s
    AURL=https://mirror.nju.edu.cn/kubernetes/apt
else
    # A. 国外
    KURL=https://packages.cloud.google.com
    AURL=https://apt.kubernetes.io/
fi

sudo curl -fsSLo $KFILE $KURL/apt/doc/apt-key.gpg

sudo tee /etc/apt/sources.list.d/kubernetes.list <<EOF >/dev/null
deb [signed-by=$KFILE] $AURL kubernetes-xenial main
EOF

sudo apt -y update


#####echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
#sudo apt-get update -y
#sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
#sudo apt-get update -y
sudo apt-get install -y jq


# 官方考试版本-CKA
CKx_URL=https://training.linuxfoundation.cn/certificates/1

:<<EOF
# 官方考试版本-CKS
CKx_URL=https://training.linuxfoundation.cn/certificates/16
EOF

KV=$(curl -s $CKx_URL | grep -Eo 软件版本.*v[0-9].[0-9]+ | awk '{print $NF}')

echo -e " The exam is based on Kubernetes: \e[1;34m${KV#v}\e[0;0m"

# 列出所有小版本
sudo apt-cache madison kubelet | grep ${KV#v}

# 安装 kubelet、kubeadm 和 kubectl 考试版本
sudo apt -y install \
    kubelet=${KV#v}.1-00 \
    kubeadm=${KV#v}.1-00 \
    kubectl=${KV#v}.1-00




local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
${ENVIRONMENT}
EOF

sudo apt-mark hold kubelet kubeadm kubectl
