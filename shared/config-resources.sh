#!/bin/bash
ISTIO_VERSION=1.9.2

#deploy metrics server
kubectl apply -f /opt/vagrant/data/components.yaml

# install istio - default profile
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
mv istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/istioctl
istioctl install -y

# install dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

# expose dashboard port to 30000
kubectl patch service kubernetes-dashboard -n kubernetes-dashboard -p '{ "spec": { "type": "NodePort", "ports": [ { "protocol": "TCP", "port": 443, "targetPort": 8443, "nodePort": 31000 } ] } }'

# create user for dashboard
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa

# Deploy Ingress
kubectl apply -f /opt/vagrant/data/ingress/ingress-namespace.yaml
kubectl apply -f /opt/vagrant/data/ingress/default-backend.yaml
kubectl apply -f /opt/vagrant/data/ingress/default-backend-service.yaml
kubectl apply -f /opt/vagrant/data/ingress/nginx-ingress-controller-configmaps.yaml
kubectl apply -f /opt/vagrant/data/ingress/nginx-ingress-controller-roles.yaml
kubectl apply -f /opt/vagrant/data/ingress/nginx-ingress-controller-deployment.yaml
kubectl apply -f /opt/vagrant/data/ingress/nginx-ingress-controller-service.yaml
kubectl apply -f /opt/vagrant/data/ingress/nginx-ingress.yaml