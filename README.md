vagrant-vagrant-kubeadm-kubernetes-containerd
介绍
使用vagrant 生成基于cka考试环境虚拟机。

基于2023年9月的CKA考题
2024年9月修改基于1.31版本。







{以下是 Gitee 平台说明，您可以替换此简介 Gitee 是 OSCHINA 推出的基于 Git 的代码托管平台（同时支持 SVN）。专为开发者提供稳定、高效、安全的云端软件开发协作平台 无论是个人、团队、或是企业，都能够用 Gitee 实现代码托管、项目管理、协作开发。企业项目请看 https://gitee.com/enterprises}

软件架构
软件架构说明

安装教程
下载vagrant https://developer.hashicorp.com/vagrant/downloads?product_intent=vagrant

window（需要用迅雷或科学）： https://releases.hashicorp.com/vagrant/2.3.7/vagrant_2.3.7_windows_amd64.msi

下载 virtualbox https://www.virtualbox.org/wiki/Downloads

虚拟机：https://download.virtualbox.org/virtualbox/7.0.10/VirtualBox-7.0.10-158379-Win.exe

虚拟机扩展：https://download.virtualbox.org/virtualbox/7.0.10/Oracle_VM_VirtualBox_Extension_Pack-7.0.10.vbox-extpack

git clone本项目，然后进入本项目目录，执行

```shell
vagrant up
```


```shell

#如果master成功完成，其它节点如worker1 有问题的话，可以
vagrant destroy worker1
vagrant up worker1
```


```shell

#setup cka联系环境
vagrant ssh master

sudo -i

/vagrant/cka/cka-setup


#cka评分

/vagrant/cka/cka-grade

```




# Vagrantfile and Scripts to Automate Kubernetes Setup using Kubeadm [Practice Environment for CKA/CKAD and CKS Exams]

## Documentation

Current k8s version for CKA, CKAD, and CKS exam: 1.27

Refer to this link for documentation: https://devopscube.com/kubernetes-cluster-vagrant/

## 🚀 CKA, CKAD, CKS, or KCNA Coupon Codes

If you are preparing for CKA, CKAD, CKS, or KCNA exam, **save 20%** today using code **SCRIPT20** at https://kube.promo/devops. It is a limited-time offer. Or Check out [Linux Foundation coupon](https://scriptcrunch.com/linux-foundation-coupon/) page for the latest voucher codes.

For the best savings, opt for the CKA + CKS bundle (**$210 Savings)**. Use code **DCUBE20** at https://kube.promo/bundle

## Prerequisites

1. Working Vagrant setup
2. 8 Gig + RAM workstation as the Vms use 3 vCPUS and 4+ GB RAM

## For MAC/Linux Users

The latest version of Virtualbox for Mac/Linux can cause issues.

Create/edit the /etc/vbox/networks.conf file and add the following to avoid any network related issues.
<pre>* 0.0.0.0/0 ::/0</pre>

or run below commands

```shell
sudo mkdir -p /etc/vbox/
echo "* 0.0.0.0/0 ::/0" | sudo tee -a /etc/vbox/networks.conf
```

So that the host only networks can be in any range, not just 192.168.56.0/21 as described here:
https://discuss.hashicorp.com/t/vagrant-2-2-18-osx-11-6-cannot-create-private-network/30984/23

## Bring Up the Cluster

To provision the cluster, execute the following commands.

```shell
git clone https://github.com/scriptcamp/vagrant-kubeadm-kubernetes.git
cd vagrant-kubeadm-kubernetes
vagrant up
```
## Set Kubeconfig file variable

```shell
cd vagrant-kubeadm-kubernetes
cd configs
export KUBECONFIG=$(pwd)/config
```

or you can copy the config file to .kube directory.

```shell
cp config ~/.kube/
```

## Install Kubernetes Dashboard

The dashboard is automatically installed by default, but it can be skipped by commenting out the dashboard version in _settings.yaml_ before running `vagrant up`.

If you skip the dashboard installation, you can deploy it later by enabling it in _settings.yaml_ and running the following:
```shell
vagrant ssh -c "/vagrant/scripts/dashboard.sh" master
```

## Kubernetes Dashboard Access

To get the login token, copy it from _config/token_ or run the following command:
```shell
kubectl -n kubernetes-dashboard get secret/admin-user -o go-template="{{.data.token | base64decode}}"
```

Proxy the dashboard:
```shell
kubectl proxy
```

Open the site in your browser:
```shell
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=kubernetes-dashboard
```

## To shutdown the cluster,

```shell
vagrant halt
```

## To restart the cluster,

```shell
vagrant up
```

## To destroy the cluster,

```shell
vagrant destroy -f
```


本项目为技术演示、学习之目的。脚本为参照培训机构东方瑞通苏振老师脚本修改及GitHub上项目修改。在此表示感谢。