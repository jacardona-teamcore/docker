kubectl create secret generic acceso-aws -n argo --from-file=credentials=credentials
kubectl create secret generic acceso-vpn -n argo --from-file=key=key