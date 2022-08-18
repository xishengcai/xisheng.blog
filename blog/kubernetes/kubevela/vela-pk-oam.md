#  Vela-pk-oam

1. 用户侧 vela 用户application 替换了 ac

2. 新增基于模版的crd

   | type     | name        | apply to                                                     | annotation                           |
   | -------- | ----------- | ------------------------------------------------------------ | ------------------------------------ |
   | workload | webservice  | workload:<br />   definition:<br />     apiVersion: apps/v1 <br />    kind: Deploym | log-runngin workload with sevice     |
   | workload | task        | workload:   <br />  definition: <br />    apiVersion: batch/v1 <br />    kind: Job | job                                  |
   | workload | worker      | workload: <br />  definition: <br />    apiVersion: apps/v1<br />     kind: Deployment | log-runngin workload without service |
   | trait    | annotations |                                                              |                                      |
   | trait    | cpuscaler   |                                                              |                                      |
   | trait    | ingress     |                                                              |                                      |
   | trait    | labels      |                                                              |                                      |
   | trait    | scaler      | - webservice <br />- worker                                  |                                      |
   | trait    | sidecar     | - webservice <br />- worker                                  |                                      |

   

3. diff


| Type |  CRD   | Controller  | From |
| ---- |  ----  | ----  | ----  |
| Control Plane Object | `applicationconfigurations.core.oam.dev` | Yes | OAM Runtime |
| Control Plane Object | `components.core.oam.dev` | Yes | OAM Runtime |
| Workload Type | `containerizedworklaods.core.oam.dev` | Yes | OAM Runtime |
| Scope | `healthscope.core.oam.dev` | Yes | OAM Runtime |
| Trait | `manualscalertraits.core.oam.dev` | Yes | OAM Runtime |
| Control Plane Object | `scopedefinitions.core.oam.dev` | No | OAM Runtime |
| Control Plane Object | `traitdefinitions.core.oam.dev` | No | OAM Runtime |
| Control Plane Object | `workloaddefinitions.core.oam.dev` | No | OAM Runtime |
| Trait | `autoscalers.standard.oam.dev` | Yes | New in KubeVela |
| Trait | `metricstraits.standard.oam.dev` | Yes | New in KubeVela |
| Workload Type | `podspecworkloads.standard.oam.dev` | Yes | New in KubeVela |
| Trait | `route.standard.oam.dev` | Yes | New in KubeVela |