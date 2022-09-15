# 从源码看kubernetes与CNI Plugin的集成

摘自： https://cloud.tencent.com/developer/article/1097399?from=article.detail.1472366



## libcni

[cni](https://github.com/containernetworking/cni)项目提供了golang写的一个library，定义了集成cni插件的应用需调用的cni plugin接口,它就是libcni。其对应的Interface定义如下：

```go
libcni/api.go:51

type CNI interface {
	AddNetworkList(net *NetworkConfigList, rt *RuntimeConf) (types.Result, error)
	DelNetworkList(net *NetworkConfigList, rt *RuntimeConf) error

	AddNetwork(net *NetworkConfig, rt *RuntimeConf) (types.Result, error)
	DelNetwork(net *NetworkConfig, rt *RuntimeConf) error
}
```



## CNI Plugin在kubelet管理的PLEG中何时被调用

kubelet Run方法方法中会最终调用syncLoopIteration函数，由它通过各种channel对pod进行sync。

```go
pkg/kubelet/kubelet.go:1794
    
// syncLoopIteration reads from various channels and dispatches pods to the
// given handler.
//
// Arguments:
// 1.  configCh:       a channel to read config events from
// 2.  handler:        the SyncHandler to dispatch pods to
// 3.  syncCh:         a channel to read periodic sync events from
// 4.  houseKeepingCh: a channel to read housekeeping events from
// 5.  plegCh:         a channel to read PLEG updates from
//
// Events are also read from the kubelet liveness manager's update channel.
//
// The workflow is to read from one of the channels, handle that event, and
// update the timestamp in the sync loop monitor.
//
// Here is an appropriate place to note that despite the syntactical
// similarity to the switch statement, the case statements in a select are
// evaluated in a pseudorandom order if there are multiple channels ready to
// read from when the select is evaluated.  In other words, case statements
// are evaluated in random order, and you can not assume that the case
// statements evaluate in order if multiple channels have events.
//
// With that in mind, in truly no particular order, the different channels
// are handled as follows:
//
// * configCh: dispatch the pods for the config change to the appropriate
//             handler callback for the event type
// * plegCh: update the runtime cache; sync pod
// * syncCh: sync all pods waiting for sync
// * houseKeepingCh: trigger cleanup of pods
// * liveness manager: sync pods that have failed or in which one or more
//                     containers have failed liveness checks
func (kl *Kubelet) syncLoopIteration(configCh <-chan kubetypes.PodUpdate, handler SyncHandler,
	syncCh <-chan time.Time, housekeepingCh <-chan time.Time, plegCh <-chan *pleg.PodLifecycleEvent) bool {
	kl.syncLoopMonitor.Store(kl.clock.Now())
	select {
	case u, open := <-configCh:
		// Update from a config source; dispatch it to the right handler
		// callback.
		if !open {
			glog.Errorf("Update channel is closed. Exiting the sync loop.")
			return false
		}
    
		switch u.Op {
		case kubetypes.ADD:
			glog.V(2).Infof("SyncLoop (ADD, %q): %q", u.Source, format.Pods(u.Pods))
			// After restarting, kubelet will get all existing pods through
			// ADD as if they are new pods. These pods will then go through the
			// admission process and *may* be rejected. This can be resolved
			// once we have checkpointing.
			handler.HandlePodAdditions(u.Pods)
		case kubetypes.UPDATE:
			glog.V(2).Infof("SyncLoop (UPDATE, %q): %q", u.Source, format.PodsWithDeletiontimestamps(u.Pods))
			handler.HandlePodUpdates(u.Pods)
		case kubetypes.REMOVE:
			glog.V(2).Infof("SyncLoop (REMOVE, %q): %q", u.Source, format.Pods(u.Pods))
			handler.HandlePodRemoves(u.Pods)
		case kubetypes.RECONCILE:
			glog.V(4).Infof("SyncLoop (RECONCILE, %q): %q", u.Source, format.Pods(u.Pods))
			handler.HandlePodReconcile(u.Pods)
		case kubetypes.DELETE:
			glog.V(2).Infof("SyncLoop (DELETE, %q): %q", u.Source, format.Pods(u.Pods))
			// DELETE is treated as a UPDATE because of graceful deletion.
			handler.HandlePodUpdates(u.Pods)
		case kubetypes.SET:
			// TODO: Do we want to support this?
			glog.Errorf("Kubelet does not support snapshot update")
		}
    
		// Mark the source ready after receiving at least one update from the
		// source. Once all the sources are marked ready, various cleanup
		// routines will start reclaiming resources. It is important that this
		// takes place only after kubelet calls the update handler to process
		// the update to ensure the internal pod cache is up-to-date.
		kl.sourcesReady.AddSource(u.Source)
	case e := <-plegCh:
		if isSyncPodWorthy(e) {
			// PLEG event for a pod; sync it.
			if pod, ok := kl.podManager.GetPodByUID(e.ID); ok {
				glog.V(2).Infof("SyncLoop (PLEG): %q, event: %#v", format.Pod(pod), e)
				handler.HandlePodSyncs([]*v1.Pod{pod})
			} else {
				// If the pod no longer exists, ignore the event.
				glog.V(4).Infof("SyncLoop (PLEG): ignore irrelevant event: %#v", e)
			}
		}
    
		if e.Type == pleg.ContainerDied {
			if containerID, ok := e.Data.(string); ok {
				kl.cleanUpContainersInPod(e.ID, containerID)
			}
		}
	case <-syncCh:
		// Sync pods waiting for sync
		podsToSync := kl.getPodsToSync()
		if len(podsToSync) == 0 {
			break
		}
		glog.V(4).Infof("SyncLoop (SYNC): %d pods; %s", len(podsToSync), format.Pods(podsToSync))
		kl.HandlePodSyncs(podsToSync)
	case update := <-kl.livenessManager.Updates():
		if update.Result == proberesults.Failure {
			// The liveness manager detected a failure; sync the pod.
    
			// We should not use the pod from livenessManager, because it is never updated after
			// initialization.
			pod, ok := kl.podManager.GetPodByUID(update.PodUID)
			if !ok {
				// If the pod no longer exists, ignore the update.
				glog.V(4).Infof("SyncLoop (container unhealthy): ignore irrelevant update: %#v", update)
				break
			}
			glog.V(1).Infof("SyncLoop (container unhealthy): %q", format.Pod(pod))
			handler.HandlePodSyncs([]*v1.Pod{pod})
		}
	case <-housekeepingCh:
		if !kl.sourcesReady.AllReady() {
			// If the sources aren't ready or volume manager has not yet synced the states,
			// skip housekeeping, as we may accidentally delete pods from unready sources.
			glog.V(4).Infof("SyncLoop (housekeeping, skipped): sources aren't ready yet.")
		} else {
			glog.V(4).Infof("SyncLoop (housekeeping)")
			if err := handler.HandlePodCleanups(); err != nil {
				glog.Errorf("Failed cleaning pods: %v", err)
			}
		}
	}
	kl.syncLoopMonitor.Store(kl.clock.Now())
	return true
}
```

- HandlePodSyncs, HandlePodUpdates, HandlePodAdditions最终都是invoke **dispatchWork**来分发pods到podWorker进行异步的pod sync。
- HandlePodRemoves调用一下接口，将pod从cache中删除，kill pod中进程，并   stop Pod的Probe Workers，最终通过捕获Pod的PLEG Event，通过**cleanUpContainersInPod**来清理Pod。 pkg/kubelet/kubelet.go:1994 kl.podManager.DeletePod(pod); kl.deletePod(pod); kl.probeManager.RemovePod(pod);
- HandlePodReconcile中，如果Pod是通过Eviction导致的Failed，则调用kl.containerDeletor.**deleteContainersInPod**来清除Pod内的[容器](https://cloud.tencent.com/product/tke?from=10680)。



## HandlePodSyncs, HandlePodUpdates, HandlePodAdditions

- Kubelet.dispatchWork最终会invoke podWokers.managePodLoop，podWorkers会嗲用NewMainKubelet时给PodWorkers注册的syncPodFn= (kl *Kubelet) syncPod(o syncPodOptions)。
- Kubelet.syncPod会根据runtime类型进行区分，我们只看runtime为[docker](https://cloud.tencent.com/product/tke?from=10680)的情况，会invoke DockerManager.SyncPod。
- DockerManager.SyncPod会dm.network.SetUpPod，然后根据network plugin类型进行区分，我们只看cni plugin，会对应invoke cniNetworkPlugin.SetUpPod进行网络设置。
- cniNetworkPlugin.SetUpPod invoke cniNetwork.addToNetwork，由后者最终调用CNIConfig.AddNetwork，这就是libcni中对应的AddNetwork Interface。
- CNIConfig.AddNetwork通过封装好的execPlugin由系统去调用cni plugin bin，到此就完成了pod内的网络设置。



## HandlePodRemoves, HandlePodReconcile

- 都是通过invoke podContainerDeleter.deleteContainerInPod来清理容器。
- 对于docker，deleteContainerInPod会调用DockerManager.delteContainer。
- 在deleteContainer时，通过invoke containerGC.netContainerCleanup进行容器的网络环境清理。
- 然后由PluginManger.TearDownPod去调用cniNetworkPlugin.TearDownPod，再执行cniNetwork.deleteFromNetwork。
- cniNetwork.deleteFromNetwork会调用CNIConfig.DelNetwork，这就是libcni中对应的DelNetwork Interface。
- CNIConfig.AddNetwork通过封装好的execPlugin由系统去调用cni plugin bin，到此就完成了pod内的网络清理。



## kubelet中与cni plugin调用的代码流程图

![img](https://ask.qcloudimg.com/http-save/yehe-1642192/2ith63c3yd.png?imageView2/2/w/1620)