#!/bin/sh

# 1 修改主机名, 并写入hosts文件中
ip=$(ifconfig |grep eth0 -A 1|grep -oP '(?<=inet )[\d\.]+(?=\s)')
echo ${ip}
if [ ${ip}x = '10.10.0.170'x ];then
    echo "set hostname k8s-master-01"
    hostnamectl set-hostname k8s-master-01

elif [ ${ip}x = '10.10.0.171'x ];then
    echo "set hostname k8s-master-02"
    hostnamectl set-hostname k8s-master-02

elif [ ${ip}x = '10.10.0.172'x ];then
    echo "set hostname k8s-master-03"
    hostnamectl set-hostname k8s-master-03
fi

echo "10.10.0.170  k8s-master-01" >> /etc/hosts
echo "10.10.0.171  k8s-master-02" >> /etc/hosts
echo "10.10.0.172  k8s-master-03" >> /etc/hosts
echo "10.10.0.190  k8s-node-01" >> /etc/hosts


# 2 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 3 关闭selinux
setenforce 0
sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
sed -i '/^SELINUX=/c SELINUX=disabled/' /etc/sysconfig/selinux

#4 关闭系统的swap
swapoff -a
sed -i 's/\(.*swap.*swap.*\)/#\1/' /etc/fstab

#5 配置sysctl
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness=0
EOF
sysctl -p /etc/sysctl.d/k8s.conf > /dev/null

#7 修改本机时区及时间同步
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "*/10 * * * * /usr/sbin/ntpdate -u ntpxdl.tcwyun.com">> /var/spool/cron/root

#8 安装所需软已经docker ce
yum install epel-release tmux mysql lrzsz -y
yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine -y

yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce-18.06.1.ce -y

#9 安装kubelet kubeadm kubectl
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum install kubelet kubeadm kubectl -y

# keepalived安装
yum install keepalived -y
\cp -rf keepalived.conf /etc/keepalived/keepalived.conf
systemctl restart keepalived
systemctl enable keepalived

#8 重启服务器
reboot
