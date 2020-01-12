#!/bin/bash
CURRENT_NODE_PRIVATE_IP=$1
CURRENT_NODE_ROLE=$2
cp /opt/vagrant/data/etc/modules-load.d/* /etc/modules-load.d/

# Disable swap
swapoff -a && \
  sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Update install docker
apt-get update \
    && apt-get upgrade -Y \
    && apt-get install -y \
        apt-transport-https \
        bash-completion \
        curl

# install docker
curl -fsSL https://get.docker.com | bash

# Set cgroup as cgroupdriver so k8s doesn't complain
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "insecure-registries": ["192.168.20.40:5000"],
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

# install k8s dependencies
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update \
    && apt-get install -y \
        kubeadm \
        kubectl \
        kubelet

# add completion commands
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'source /usr/share/bash-completion/bash_completion' >>~/.bashrc

# Fix the ip route in case we are using multiple network interfaces
# This command covers the default network for VIPs (10.96.0.0/12) as
# per the kubernetes documentation: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
# More on https://github.com/weaveworks/weave/issues/3599
ip route add 10.96.0.0/12 dev enp0s8 src $CURRENT_NODE_PRIVATE_IP

# Kubelet extra args:
# - https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
# - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/
cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=$CURRENT_NODE_PRIVATE_IP
EOF
systemctl daemon-reload \
  && systemctl restart kubelet

# start the k8s cluster on master node
if [[ $CURRENT_NODE_ROLE == 'master' ]]; then
  kubeadm config images pull \
      && kubeadm init --apiserver-advertise-address $CURRENT_NODE_PRIVATE_IP --apiserver-cert-extra-sans $CURRENT_NODE_PRIVATE_IP --node-name $(hostname -s)

  # copy the config files so you can properly manage your cluster
  rm -rf $HOME/.kube
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # install the pod network
  kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  
  # copy join command and config so it is shared along the instances
  rm -rf /opt/vagrant/data/.k8s && mkdir -p /opt/vagrant/data/.k8s
  kubeadm token create --print-join-command >> /opt/vagrant/data/.k8s/kubeadm_join.sh
  chmod +x /opt/vagrant/data/.k8s/kubeadm_join.sh

  cp -i /etc/kubernetes/admin.conf /opt/vagrant/data/.k8s/admin.conf

else
  if [[ $CURRENT_NODE_ROLE == 'worker' ]]; then
    # Join the cluster
    /opt/vagrant/data/.k8s/kubeadm_join.sh
  else
    curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    docker container run -d --name private-registry -p 5000:5000 registry:2
  fi
fi