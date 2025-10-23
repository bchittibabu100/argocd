#!/bin/bash
echo -n "Enter argocd admin password: "
read argocd_password

export host_ip=`hostname -i | cut -d' ' -f 2`
echo -e "Installing ArgoCD Agent"
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
kubectl create ns argocd
kubectl create -f `pwd`/argocd_manifest.yaml -n argocd
echo "\n"
echo "Please wait for argocd initilization to complete...."
echo "\n"
bash pod_status_argocd.sh

echo "username: admin"
export argo_pass=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo`
echo "argocd_pass: $argo_pass"
echo "Use above credentials to reset default password of arogcd UI"
echo "============================================================="
argocd login $host_ip:30303 --insecure --grpc-web
argocd account update-password
echo "\n"
echo "Now acess argocd at https://$host_ip:30303"
