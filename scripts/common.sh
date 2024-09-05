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
#sudo apt-get update -y
# Install CRI-O Runtime

VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+')"



# Which services should be restarted?
NFILE=/etc/needrestart/needrestart.conf

sudo sed -i \
   -e '/nrconf{restart}/{s+i+a+;s+#++}'  \
   $NFILE

grep nrconf{restart} $NFILE



if ! curl --connect-timeout 2 google.com &>/dev/null; then
   # C. 国内
   MIRROR_URL=http://mirror.nju.edu.cn/ubuntu
   CODE_NAME=$(lsb_release -cs)
   COMPONENT="main restricted universe multiverse"

   # 生成软件仓库源
   sudo tee /etc/apt/sources.list >/dev/null <<EOF
deb $MIRROR_URL $CODE_NAME $COMPONENT
deb $MIRROR_URL $CODE_NAME-updates $COMPONENT
deb $MIRROR_URL $CODE_NAME-backports $COMPONENT
deb $MIRROR_URL $CODE_NAME-security $COMPONENT
EOF
fi

cat /etc/apt/sources.list



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

ROOT_PASS=vagrant

(echo $ROOT_PASS; echo $ROOT_PASS) \
   | sudo passwd root

echo PermitRootLogin yes \
   | sudo tee -a /etc/ssh/sshd_config

sudo systemctl restart sshd

timedatectl set-timezone Asia/Shanghai



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
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  #  | sudo apt-key add -
curl -fsSL https://mirror.nju.edu.cn/docker-ce/linux/ubuntu/gpg  \
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
        -e "/sandbox_image/s+registry.k8s.io/pause:3.6+registry.aliyuncs.com/google_containers/pause:3.9+" \
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

#TFILE=crictl-v1.28.0-linux-amd64.tar.gz
TFILE=crictl-v1.31.1-linux-amd64.tar.gz
#curl -LO# $CURL/$TFILE

#curl -LO# https://gitee.com/wangmt2000/share/releases/download/ccrictl/crictl-v1.28.0-linux-amd64.tar.gz
curl -LO# https://gitee.com/wangmt2000/share/releases/download/ccrictl1.31/crictl-v1.31.1-linux-amd64.tar.gz

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
#sudo mkdir /etc/apt/keyrings

if [ ! -d "/etc/apt/keyrings" ]; then
    # 如果不存在，尝试创建目录
    sudo mkdir /etc/apt/keyrings
    if [ $? -ne 0 ]; then
        echo "创建 /etc/apt/keyrings 目录失败，但不影响后续操作。"
    else
        echo "成功创建 /etc/apt/keyrings 目录。"
    fi
else
    echo "/etc/apt/keyrings 目录已存在，继续执行后续操作。"
fi

#if ! curl --connect-timeout 2 google.com &>/dev/null; then
  # C. 国内
  export AURL=http://mirrors.aliyun.com/kubernetes-new/core/stable/v1.31/deb
#else
  # F. 国外
 # export AURL=http://pkgs.k8s.io/core:/stable:/v1.29/deb
#fi
  export KFILE=/etc/apt/keyrings/kubernetes-apt-keyring.gpg
  curl -fsSL ${AURL}/Release.key \
    | sudo gpg --dearmor -o ${KFILE}
  sudo tee /etc/apt/sources.list.d/kubernetes.list <<-EOF
deb [signed-by=${KFILE}] ${AURL} /
EOF



#####echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
#sudo apt-get update -y
#sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
sudo apt-get update -y
sudo apt-get install -y jq


# 官方考试版本-CKA
#CKx_URL=https://training.linuxfoundation.cn/certificates/1

#:<<EOF
# 官方考试版本-CKS
#CKx_URL=https://training.linuxfoundation.cn/certificates/16
#EOF

#KV=$(curl -s $CKx_URL | grep -Eo 软件版本.*v[0-9].[0-9]+ | awk '{print $NF}')
KV=1.31

echo -e " The exam is based on Kubernetes: \e[1;34m${KV#v}\e[0;0m"

# 列出所有小版本
#sudo apt-cache madison kubelet | grep ${KV#v}
sudo apt-cache madison kubelet 
# 安装 kubelet、kubeadm 和 kubectl 考试版本
sudo apt -y install \
    kubelet=${KV#v}.0-1.1 \
    kubeadm=${KV#v}.0-1.1 \
    kubectl=${KV#v}.0-1.1




local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
${ENVIRONMENT}
EOF

sudo apt-mark hold kubelet kubeadm kubectl
