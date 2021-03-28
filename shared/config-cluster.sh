#!/bin/bash
CURRENT_NODE_PRIVATE_IP=$1
CURRENT_NODE_ROLE=$2
OS=xUbuntu_20.04
VERSION=1.20
CIDR=10.244.0.0/16

#disable swap
swapoff -a &&   sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Configures network to user cri-o
modprobe overlay
modprobe br_netfilter

cat << EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Set Extra-args to use cri-o and vagrant ip
cat << EOF | tee /etc/default/kubelet 
KUBELET_EXTRA_ARGS=--feature-gates="AllAlpha=false,RunAsGroup=true" --container-runtime=remote --cgroup-driver=systemd --container-runtime-endpoint='unix:///var/run/crio/crio.sock' --runtime-request-timeout=5m --node-ip=$CURRENT_NODE_PRIVATE_IP
EOF

sysctl --system

# Install Cri-o
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -

apt-get update
apt-get install cri-o cri-o-runc -y

# Download k8s key
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update

#enalbe cri-o services
systemctl enable cri-o.service
systemctl start cri-o.service
systemctl status cri-o.service

#install k8s-tools
apt-get install -y kubeadm kubectl kubelet

# add completion commands
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'source /usr/share/bash-completion/bash_completion' >>~/.bashrc

# resolves additional IP information on virtualbox
ip route add 10.96.0.0/12 dev enp0s8 src $CURRENT_NODE_PRIVATE_IP

systemctl daemon-reload \
  && systemctl restart kubelet

if [[ $CURRENT_NODE_ROLE == 'master' ]]; then
    kubeadm init --pod-network-cidr=10.88.0.0/16 --apiserver-advertise-address $CURRENT_NODE_PRIVATE_IP --apiserver-cert-extra-sans $CURRENT_NODE_PRIVATE_IP --node-name $(hostname -s)

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # apply calico
    kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml

    rm -rf /opt/vagrant/data/.k8s && mkdir -p /opt/vagrant/data/.k8s
    kubeadm token create --print-join-command >> /opt/vagrant/data/.k8s/kubeadm_join.sh
    chmod +x /opt/vagrant/data/.k8s/kubeadm_join.sh

    cp -i /etc/kubernetes/admin.conf /opt/vagrant/data/.k8s/admin.conf

else
  if [[ $CURRENT_NODE_ROLE == 'worker' ]]; then
    # Join the cluster
    /opt/vagrant/data/.k8s/kubeadm_join.sh
  fi
fi
