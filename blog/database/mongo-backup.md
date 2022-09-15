# mongodb backup

```bash
mongorestore --host localhost:27017 -u root -p 123456 --authenticationDatabase=admin --dir=./dump

mongodump --host x.x.x.x:27017 -u root -p passw --authenticationDatabase=admin --db=testdb -o /data/dump_testdb
```





MongoDB&reg; can be accessed on the following DNS name(s) and ports from within your cluster:



  mongodb-0.mongodb-headless.middleware-dev.svc.cluster.local:27017

  mongodb-1.mongodb-headless.middleware-dev.svc.cluster.local:27017



To get the root password run:



  export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace middleware-dev mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)



To connect to your database, create a MongoDB&reg; client container:



  kubectl run --namespace middleware-dev mongodb-client --rm --tty -i --restart='Never' --env="MONGODB_ROOT_PASSWORD=$MONGODB_ROOT_PASSWORD" --image docker.io/bitnami/mongodb:6.0.1-debian-11-r0 --command -- bash



Then, run the following command:

  mongosh admin --host "mongodb-0.mongodb-headless.middleware-dev.svc.cluster.local:27017,mongodb-1.mongodb-headless.middleware-dev.svc.cluster.local:27017" --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD