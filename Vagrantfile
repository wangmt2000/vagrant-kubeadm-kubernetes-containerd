
require "yaml"
settings = YAML.load_file "settings.yaml"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]

Vagrant.configure("2") do |config|
  config.vm.provision "shell", env: { "IP_NW" => IP_NW, "IP_START" => IP_START, "NUM_WORKER_NODES" => NUM_WORKER_NODES }, inline: <<-SHELL
    #  apt-get update -y
      echo "$IP_NW$((IP_START)) k8s-master" >> /etc/hosts
      for i in `seq 1 ${NUM_WORKER_NODES}`; do
        echo "$IP_NW$((IP_START+i)) k8s-worker${i}" >> /etc/hosts
      done
  SHELL

  if `uname -m`.strip == "aarch64"
    config.vm.box = settings["software"]["box"] + "-arm64"
  else
    config.vm.box = settings["software"]["box"]
  end
  config.vm.box_check_update = true
  config.ssh.disable_deprecated_algorithms = true
  #此设置将 未将 SSH 客户端配置为允许使用 SSH-RSA 密钥类型连接到主机 和主机密钥算法。默认值为 false
  config.ssh.insert_key = false
  #当前自动插入重新生成ssh-key，有概率导致失败。
  #默认情况下，如果设置为 ，Vagrant 将自动插入 用于 SSH 的密钥对，替换 Vagrant 在机器内默认的不安全密钥 如果检测到。
  #如果您已经使用私钥对访客进行身份验证，或者依赖 在默认的不安全密钥上，将不使用此选项。如果设置为false 
  #Vagrant 不会自动向客户机添加密钥对。truefalse
  #vm https://developer.hashicorp.com/vagrant/docs/vagrantfile/machine_settings
#  ssh  https://developer.hashicorp.com/vagrant/docs/vagrantfile/ssh_settings
  config.vm.define "master" do |master|
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", ip: settings["network"]["control_ip"]
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    master.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["nodes"]["control"]["cpu"]
        vb.memory = settings["nodes"]["control"]["memory"]
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    master.vm.provision "shell",
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "OS" => settings["software"]["os"]
      },
      path: "scripts/common.sh"
    master.vm.provision "shell",
      env: {
        "CALICO_VERSION" => settings["software"]["calico"],
        "CONTROL_IP" => settings["network"]["control_ip"],
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"]
      },
      path: "scripts/master.sh"
  end

  (1..NUM_WORKER_NODES).each do |i|

    config.vm.define "worker#{i}" do |node|
      node.vm.hostname = "k8s-worker#{i}"
      node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb|
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell",
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "OS" => settings["software"]["os"]
        },
        path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/node.sh"

      # Only install the dashboard after provisioning the last worker (and when enabled).
     # if i == NUM_WORKER_NODES and settings["software"]["dashboard"] and settings["software"]["dashboard"] != ""
      #  node.vm.provision "shell", path: "scripts/dashboard.sh"
      #end
    end

  end
end 
