# Provision an APNMT EKS Cluster

## Create Kubernetes Cluster
```
terraform plan
terraform apply
```

## Configure kubectl to connect to created Cluster
```
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```
