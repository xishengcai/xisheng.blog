### ETCD
etcd is a consistent and highly-available key value store used as Kubernetes’ backing store for all cluster data.

If your Kubernetes cluster uses etcd as its backing store, make sure you have a back up plan for those data.

You can find in-depth information about etcd in the official [documentation](https://etcd.io/docs/v3.4.0/).

env requires
- etcd version 3.4.3

- kuberentes 1.17.0

  

#### run etcd in kubernets
login you k8s master node:

cat /etc/kubernetes/manifests/etcd.yaml
```bash
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    component: etcd
    tier: control-plane
  name: etcd
  namespace: kube-system
spec:
  containers:
  - command:
    - etcd
    - --advertise-client-urls=https://192.168.1.33:2379
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --client-cert-auth=true
    - --data-dir=/var/lib/etcd
    - --initial-advertise-peer-urls=https://192.168.1.33:2380
    - --initial-cluster=e1192523-1d5d-43fa-b0ed-80cfffed0de0=https://192.168.1.33:2380
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --listen-client-urls=https://127.0.0.1:2379,https://192.168.1.33:2379
    - --listen-metrics-urls=http://127.0.0.1:2381
    - --listen-peer-urls=https://192.168.1.33:2380
    - --name=e1192523-1d5d-43fa-b0ed-80cfffed0de0
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-client-cert-auth=true
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --snapshot-count=10000
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    image: registry.aliyuncs.com/google_containers/etcd:3.4.3-0
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: 127.0.0.1
        path: /health
        port: 2381
        scheme: HTTP
      initialDelaySeconds: 15
      timeoutSeconds: 15
    name: etcd
    resources: {}
    volumeMounts:
    - mountPath: /var/lib/etcd
      name: etcd-data
    - mountPath: /etc/kubernetes/pki/etcd
      name: etcd-certs
  hostNetwork: true
  priorityClassName: system-cluster-critical
  volumes:
  - hostPath:
      path: /etc/kubernetes/pki/etcd
      type: DirectoryOrCreate
    name: etcd-certs
  - hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
status: {}
```


#### etcd operation
find etcd on kubernetes
```bash
[root@master-1 ~]# kubectl -n kube-system get pods -l component=etcd
NAME                                        READY   STATUS    RESTARTS   AGE
etcd-e1192523-1d5d-43fa-b0ed-80cfffed0de0   1/1     Running   0          3h5m
etcd-f61b71cb-8a86-4873-8223-eac734ec6964   1/1     Running   0          138m

```
attach etcd container
```bash
kubectl exec -it etcd-e1192523-1d5d-43fa-b0ed-80cfffed0de0  sh -n kube-system
```

alias
```bash
export ETCDCTL_API=3
etl='etcdctl --cacert=ca.crt --cert=healthcheck-client.crt --key=healthcheck-client.key'
```

list all keys
```bash
etl get / --prefix --keys-only
```

get key
```bash
etl get /registry/services/specs/default/kubernetes
```

```bash
OPTIONS:
      --cacert=""				verify certificates of TLS-enabled secure servers using this CA bundle
      --cert=""					identify secure client using this TLS certificate file
      --command-timeout=5s			timeout for short running command (excluding dial timeout)
      --debug[=false]				enable client-side debug logging
      --dial-timeout=2s				dial timeout for client connections
  -d, --discovery-srv=""			domain name to query for SRV records describing cluster endpoints
      --discovery-srv-name=""			service name to query when using DNS discovery
      --endpoints=[127.0.0.1:2379]		gRPC endpoints
  -h, --help[=false]				help for etcdctl
      --hex[=false]				print byte strings as hex encoded strings
      --insecure-discovery[=true]		accept insecure SRV records describing cluster endpoints
      --insecure-skip-tls-verify[=false]	skip server certificate verification
      --insecure-transport[=true]		disable transport security for client connections
      --keepalive-time=2s			keepalive time for client connections
      --keepalive-timeout=6s			keepalive timeout for client connections
      --key=""					identify secure client using this TLS key file
      --password=""				password for authentication (if this option is used, --user option shouldn't include password)
      --user=""					username[:password] for authentication (prompt if password is not supplied)
  -w, --write-out="simple"			set the output format (fields, json, protobuf, simple, table)

```

#### backing up at etcd cluster
#### build-in snapshot
etcd supports built-in snapshot, so backing up an etcd cluster is easy. A snapshot may either be taken from a live member with the etcdctl snapshot save command or by copying the member/snap/db file from an etcd data directory that is not currently used by an etcd process. Taking the snapshot will normally not affect the performance of the member.

Below is an example for taking a snapshot of the keyspace served by $ENDPOINT to the file snapshotdb:

```bash
ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save /var/lib/etcd/snapshot-20200312.db
# exit 0

# verify the snapshot
etcdctl --write-out=table snapshot status /var/lib/etcd/snapshot-20200312.db
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| c5a9f6c7 |    22904 |       1491 |     1.8 MB |
+----------+----------+------------+------------+


```

#### start etcd
**Single-node etcd cluster**
1. Run the following
```bash
./etcd --listen-client-urls=http://$PRIVATE_IP:2379 --advertise-client-urls=http://$PRIVATE_IP:2379
```
2. Start Kuebrentes API server with the flag --etcd-servers=$PRIVATE_IP:2379
> Replace PRIVATE_IP with your etcd client IP

**Multi-node etcd cluster**

To run a load balancing etcd cluster:

1. Set up an etcd cluster.
2. Configure a load balancer in front of the etcd cluster. For example, let the address of the load balancer be $LB.
3. Start Kubernetes API Servers with the flag --etcd-servers=$LB:2379.

#### Securing etcd clusters
To secure etcd, either set up firewall rules or use the security features provided by etcd.
etcd security features depend on x509 Public Key Infrastructure(PKI).　To begin,
establish secure communication channels by generating a key and certificate pair. 

For example,

**securing communication between etcd members**
> use key pairs peer.key and peer.cert

**securing communication between etcd and its clients**
>use client.key and client.cert .

more example see [script provided](https://github.com/coreos/etcd/tree/master/hack/tls-setup) provided by the etcd 
project to generate key pairs and CA files for client authentication.
                                    
#### Limiting access of etcd clusters
After configuring secure communication, restrict the access of etcd cluster to only the Kubernetes API server. Use TLS authentication to do so.

For example, consider key pairs k8sclient.key and k8sclient.cert that are trusted by the CA etcd.ca. When etcd is 
configured with --client-cert-auth along with TLS, it verifies the certificates from clients by using 
system CAs or the CA passed in by --trusted-ca-file flag. Specifying flags --client-cert-auth=true and 
--trusted-ca-file=etcd.ca will restrict the access to clients with the certificate k8sclient.cert.

Once etcd is configured correctly, only clients with valid certificates can access it. 
To give Kubernetes API server the access, configure it with the flags 
--etcd-certfile=k8sclient.cert,
--etcd-keyfile=k8sclient.key and
--etcd-cafile=ca.cert.

使用三个文件ca.crt, xx.key, xx.crt  连接etcd endpoint

reference:
- https://kubernetes.io/zh/docs/tasks/administer-cluster/configure-upgrade-etcd/

