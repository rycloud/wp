#/bin/sh

RESOURCEGROUP=rg-rediscluster

str=`az ad sp create-for-rbac --skip-assignment -o tsv`
APPID=`echo $str | awk -F " " '{print $1}'`
PASSWD=`echo $str | awk -F " " '{print $4}'`
echo "AppId:" $APPID 
echo "Password:" $PASSWD
sleep 10

az group create --name $RESOURCEGROUP --location westus2
az network vnet create -g $RESOURCEGROUP -n vnet1 --address-prefix 192.168.0.0/16 --subnet-name subnet1 --subnet-prefix 192.168.1.0/24  


VNET_ID=$(az network vnet show --resource-group $RESOURCEGROUP --name vnet1 --query id -o tsv)
SUBNET_ID=$(az network vnet subnet list --resource-group $RESOURCEGROUP --vnet-name vnet1 --query [].id --output tsv)

az role assignment create --assignee $APPID --scope $VNET_ID --role Contributor

az aks create \
    --resource-group  $RESOURCEGROUP \
    --name rediscluster \
    --node-count 3 \
    --node-vm-size Standard_DS2_v2 \
    --vm-set-type AvailabilitySet \
    --network-plugin azure \
    --vnet-subnet-id $SUBNET_ID \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --load-balancer-sku Standard \
    --service-principal  $APPID \
    --client-secret $PASSWD \
    --generate-ssh-keys \
    --output json

az aks get-credentials -g $RESOURCEGROUP -n redisakscluster

kubectl get nodes

echo "Deploy StatefulSet with PV"
kubectl apply -f redis-sts.yaml
kubectl apply -f redis-svc.yaml

#kubectl get service redis --watch
#kubectl exec -it <Pod> -c redis bash
#kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
#az aks browse --resource-group  $RESOURCEGROUP  --name redisakscluster 
