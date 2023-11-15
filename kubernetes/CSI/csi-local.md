# Local  PV



## 使用背景

1. hostPath 需要指定Node
2. 需要事先创建好目录，而且要注意权限配置，比如root用户创建的目录，普通用户无法使用
3. 不能指定大小，可能会面临磁盘被写满的危险，而且没有I/O隔离机制
4. statefulset不能使用hostPath Volume，写好的Helm不能兼容hostPath volume



#### Local PV使用场景

适用于高优先级系统，需要在多个不同节点上存储数据，而且I/O要求较高。



## Local PV 与常规PV 的区别

对于常规的PV，Kubernetes都是先调度Pod到某个节点上，然后再持久化这台机器上的Volume目录。而Local PV，则需要运维人员提前准备好节点的磁盘，当Pod调度的时候要考虑这些LocalPV的分布



## 创建Local PV && PVC && StorageClass

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-local-pv
spec:
  capacity:
    storage: 5Gi 
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - my-node
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: example-local-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi 
  storageClassName: local-storage
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer

```

上面的 PV 限制了 节点和路径

![preview](https://segmentfault.com/img/bVcVGYJ/view)

#### StorageClass延迟绑定机制

![image.png](https://segmentfault.com/img/bVcVHgE)

provisioner 字段定义为no-provisioner，这是因为 Local Persistent Volume 目前尚不支持 Dynamic Provisioning动态生成PV，所以我们需要提前手动创建PV。

volumeBindingMode字段定义为WaitForFirstConsumer，它是 Local Persistent Volume 里一个非常重要的特性，即：延迟绑定。延迟绑定就是在我们提交PVC文件时，StorageClass为我们延迟绑定PV与PVC的对应关系。

这样做的原因是：比如我们在当前集群上有两个相同属性的PV，它们分布在不同的节点Node1和Node2上，而我们定义的Pod需要运行在Node1节点上 ，但是StorageClass已经为Pod声明的PVC绑定了在Node2上的PV，这样的话，Pod调度就会失败，所以我们要延迟StorageClass的绑定操作。

也就是延迟到到第一个声明使用该 PVC 的 Pod 出现在调度器之后，调度器再综合考虑所有的调度规则，当然也包括每个 PV 所在的节点位置，来统一决定，这个 Pod 声明的 PVC，到底应该跟哪个 PV 进行绑定。

#### Local PV最佳实践

<1>

为了更好的IO隔离效果，建议将一整块磁盘作为一个存储卷使用；
<2>为了得到存储空间的隔离，建议为每个存储卷使用一个独立的磁盘分区；
<3>在仍然存在指定了某个node节点的亲和性关系的旧PV时，要避免重新创建具有相同节点名称的node节点。 否则，系统可能会认为新节点包含旧的PV。
<4>对于具有文件系统的存储卷，建议在fstab条目和该卷的mount安装点的目录名中使用它们的UUID（例如ls -l /dev/disk/by-uuid的输出）。 这种做法可确保不会安装错误的本地卷，即使其设备路径发生了更改（例如，如果/dev/sda1在添加新磁盘时变为/dev/sdb1）。 此外，这种做法将确保如果创建了具有相同名称的另一个节点时，该节点上的任何卷仍然都会是唯一的，而不会被误认为是具有相同名称的另一个节点上的卷。
<5>对于没有文件系统的原始块存储卷，请使用其唯一ID作为符号链接的名称。 根据您的环境，/dev/disk/by-id/中的卷ID可能包含唯一的硬件序列号。 否则，应自行生成一个唯一ID。 符号链接名称的唯一性将确保如果创建了另一个具有相同名称的节点，则该节点上的任何卷都仍然是唯一的，而不会被误认为是具有相同名称的另一个节点上的卷。

#### Local PV 局限性

在使用Local PV进行测试的时候，是无法对Pod使用的Local PV容量进行限制的，Pod会一直使用挂载的Local PV的容量。因此，Local PV不支持动态的PV空间申请管理。也就是说，需要手动对Local PV进行容量规划，需要对能够使用的本地资源做一个全局规划，然后划分为各种尺寸的卷后挂载到自动发现目录下。
如果容器分配的一个存储空间不够用了怎么办？
建议使用Linux下的LVM（逻辑分区管理）来管理每个node节点上的本地磁盘存储空间。
<1>创建一个大的VG分组，把一个node节点上可以使用的存储空间都放进去；
<2>按未来一段时间内的容器存储空间使用预期，提前批量创建出一部分逻辑卷LVs，都挂载到自动发现目录下去；
<3>不要把VG中的存储资源全部用尽，预留少部分用于未来给个别容器扩容存储空间的资源；
<4>使用lvextend为特定容器使用的存储卷进行扩容；



## 基本实现原理



```go
// Run starts all of this controller's control loops
func (ctrl *PersistentVolumeController) Run(ctx context.Context) {
	defer utilruntime.HandleCrash()
	defer ctrl.claimQueue.ShutDown()
	defer ctrl.volumeQueue.ShutDown()

	klog.Infof("Starting persistent volume controller")
	defer klog.Infof("Shutting down persistent volume controller")

	if !cache.WaitForNamedCacheSync("persistent volume", ctx.Done(), ctrl.volumeListerSynced, ctrl.claimListerSynced, ctrl.classListerSynced, ctrl.podListerSynced, ctrl.NodeListerSynced) {
		return
	}

	ctrl.initializeCaches(ctrl.volumeLister, ctrl.claimLister)

	go wait.Until(ctrl.resync, ctrl.resyncPeriod, ctx.Done())
	go wait.UntilWithContext(ctx, ctrl.volumeWorker, time.Second)
	go wait.UntilWithContext(ctx, ctrl.claimWorker, time.Second)

	metrics.Register(ctrl.volumes.store, ctrl.claims, &ctrl.volumePluginMgr)

	<-ctx.Done()
}
```

上述run函数是入口，主要是启动三个goroutine，里面三个重要的方法分别是 resync， volumeWorker， claimWorker。resync主要作用是将同步到的PV和PVC放置到volumeQueue和claimQueue中，供volumeWorker和claimWorker消费。



volumeWorker

volumeworker不断循环消费volumeQueue中的数据，volumeWorker中主要的是updateVolume函数，代码如下：

```go
// updateVolume runs in worker thread and handles "volume added",
// "volume updated" and "periodic sync" events.
func (ctrl *PersistentVolumeController) updateVolume(ctx context.Context, volume *v1.PersistentVolume) {
	// Store the new volume version in the cache and do not process it if this
	// is an old version.
	new, err := ctrl.storeVolumeUpdate(volume)
	if err != nil {
		klog.Errorf("%v", err)
	}
	if !new {
		return
	}

	err = ctrl.syncVolume(ctx, volume)
	if err != nil {
		if errors.IsConflict(err) {
			// Version conflict error happens quite often and the controller
			// recovers from it easily.
			klog.V(3).Infof("could not sync volume %q: %+v", volume.Name, err)
		} else {
			klog.Errorf("could not sync volume %q: %+v", volume.Name, err)
		}
	}
}
```

updateVolume函数主要是调用syncVolume函数，syncVolume函数如下：

```go
// syncVolume is the main controller method to decide what to do with a volume.
// It's invoked by appropriate cache.Controller callbacks when a volume is
// created, updated or periodically synced. We do not differentiate between
// these events.
func (ctrl *PersistentVolumeController) syncVolume(ctx context.Context, volume *v1.PersistentVolume) error {
	klog.V(4).Infof("synchronizing PersistentVolume[%s]: %s", volume.Name, getVolumeStatusForLogging(volume))
	// Set correct "migrated-to" annotations and modify finalizers on PV and update in API server if
	// necessary
	newVolume, err := ctrl.updateVolumeMigrationAnnotationsAndFinalizers(ctx, volume)
	if err != nil {
		// Nothing was saved; we will fall back into the same
		// condition in the next call to this method
		return err
	}
	volume = newVolume

	// [Unit test set 4]
	if volume.Spec.ClaimRef == nil {
		// Volume is unused
		klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume is unused", volume.Name)
		if _, err := ctrl.updateVolumePhase(volume, v1.VolumeAvailable, ""); err != nil {
			// Nothing was saved; we will fall back into the same
			// condition in the next call to this method
			return err
		}
		return nil
	} else /* pv.Spec.ClaimRef != nil */ {
		// Volume is bound to a claim.
		if volume.Spec.ClaimRef.UID == "" {
			// The PV is reserved for a PVC; that PVC has not yet been
			// bound to this PV; the PVC sync will handle it.
			klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume is pre-bound to claim %s", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef))
			if _, err := ctrl.updateVolumePhase(volume, v1.VolumeAvailable, ""); err != nil {
				// Nothing was saved; we will fall back into the same
				// condition in the next call to this method
				return err
			}
			return nil
		}
		klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume is bound to claim %s", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef))
		// Get the PVC by _name_
		var claim *v1.PersistentVolumeClaim
		claimName := claimrefToClaimKey(volume.Spec.ClaimRef)
		obj, found, err := ctrl.claims.GetByKey(claimName)
		if err != nil {
			return err
		}
		if !found {
			// If the PV was created by an external PV provisioner or
			// bound by external PV binder (e.g. kube-scheduler), it's
			// possible under heavy load that the corresponding PVC is not synced to
			// controller local cache yet. So we need to double-check PVC in
			//   1) informer cache
			//   2) apiserver if not found in informer cache
			// to make sure we will not reclaim a PV wrongly.
			// Note that only non-released and non-failed volumes will be
			// updated to Released state when PVC does not exist.
			if volume.Status.Phase != v1.VolumeReleased && volume.Status.Phase != v1.VolumeFailed {
				obj, err = ctrl.claimLister.PersistentVolumeClaims(volume.Spec.ClaimRef.Namespace).Get(volume.Spec.ClaimRef.Name)
				if err != nil && !apierrors.IsNotFound(err) {
					return err
				}
				found = !apierrors.IsNotFound(err)
				if !found {
					obj, err = ctrl.kubeClient.CoreV1().PersistentVolumeClaims(volume.Spec.ClaimRef.Namespace).Get(context.TODO(), volume.Spec.ClaimRef.Name, metav1.GetOptions{})
					if err != nil && !apierrors.IsNotFound(err) {
						return err
					}
					found = !apierrors.IsNotFound(err)
				}
			}
		}
		if !found {
			klog.V(4).Infof("synchronizing PersistentVolume[%s]: claim %s not found", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef))
			// Fall through with claim = nil
		} else {
			var ok bool
			claim, ok = obj.(*v1.PersistentVolumeClaim)
			if !ok {
				return fmt.Errorf("cannot convert object from volume cache to volume %q!?: %#v", claim.Spec.VolumeName, obj)
			}
			klog.V(4).Infof("synchronizing PersistentVolume[%s]: claim %s found: %s", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef), getClaimStatusForLogging(claim))
		}
		if claim != nil && claim.UID != volume.Spec.ClaimRef.UID {
			// The claim that the PV was pointing to was deleted, and another
			// with the same name created.
			// in some cases, the cached claim is not the newest, and the volume.Spec.ClaimRef.UID is newer than cached.
			// so we should double check by calling apiserver and get the newest claim, then compare them.
			klog.V(4).Infof("Maybe cached claim: %s is not the newest one, we should fetch it from apiserver", claimrefToClaimKey(volume.Spec.ClaimRef))

			claim, err = ctrl.kubeClient.CoreV1().PersistentVolumeClaims(volume.Spec.ClaimRef.Namespace).Get(context.TODO(), volume.Spec.ClaimRef.Name, metav1.GetOptions{})
			if err != nil && !apierrors.IsNotFound(err) {
				return err
			} else if claim != nil {
				// Treat the volume as bound to a missing claim.
				if claim.UID != volume.Spec.ClaimRef.UID {
					klog.V(4).Infof("synchronizing PersistentVolume[%s]: claim %s has a newer UID than pv.ClaimRef, the old one must have been deleted", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef))
					claim = nil
				} else {
					klog.V(4).Infof("synchronizing PersistentVolume[%s]: claim %s has a same UID with pv.ClaimRef", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef))
				}
			}
		}

		if claim == nil {
			// If we get into this block, the claim must have been deleted;
			// NOTE: reclaimVolume may either release the PV back into the pool or
			// recycle it or do nothing (retain)

			// Do not overwrite previous Failed state - let the user see that
			// something went wrong, while we still re-try to reclaim the
			// volume.
			if volume.Status.Phase != v1.VolumeReleased && volume.Status.Phase != v1.VolumeFailed {
				// Also, log this only once:
				klog.V(2).Infof("volume %q is released and reclaim policy %q will be executed", volume.Name, volume.Spec.PersistentVolumeReclaimPolicy)
				if volume, err = ctrl.updateVolumePhase(volume, v1.VolumeReleased, ""); err != nil {
					// Nothing was saved; we will fall back into the same condition
					// in the next call to this method
					return err
				}
			}
			if err = ctrl.reclaimVolume(volume); err != nil {
				// Release failed, we will fall back into the same condition
				// in the next call to this method
				return err
			}
			if volume.Spec.PersistentVolumeReclaimPolicy == v1.PersistentVolumeReclaimRetain {
				// volume is being retained, it references a claim that does not exist now.
				klog.V(4).Infof("PersistentVolume[%s] references a claim %q (%s) that is not found", volume.Name, claimrefToClaimKey(volume.Spec.ClaimRef), volume.Spec.ClaimRef.UID)
			}
			return nil
		} else if claim.Spec.VolumeName == "" {
			if pvutil.CheckVolumeModeMismatches(&claim.Spec, &volume.Spec) {
				// Binding for the volume won't be called in syncUnboundClaim,
				// because findBestMatchForClaim won't return the volume due to volumeMode mismatch.
				volumeMsg := fmt.Sprintf("Cannot bind PersistentVolume to requested PersistentVolumeClaim %q due to incompatible volumeMode.", claim.Name)
				ctrl.eventRecorder.Event(volume, v1.EventTypeWarning, events.VolumeMismatch, volumeMsg)
				claimMsg := fmt.Sprintf("Cannot bind PersistentVolume %q to requested PersistentVolumeClaim due to incompatible volumeMode.", volume.Name)
				ctrl.eventRecorder.Event(claim, v1.EventTypeWarning, events.VolumeMismatch, claimMsg)
				// Skipping syncClaim
				return nil
			}

			if metav1.HasAnnotation(volume.ObjectMeta, pvutil.AnnBoundByController) {
				// The binding is not completed; let PVC sync handle it
				klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume not bound yet, waiting for syncClaim to fix it", volume.Name)
			} else {
				// Dangling PV; try to re-establish the link in the PVC sync
				klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume was bound and got unbound (by user?), waiting for syncClaim to fix it", volume.Name)
			}
			// In both cases, the volume is Bound and the claim is Pending.
			// Next syncClaim will fix it. To speed it up, we enqueue the claim
			// into the controller, which results in syncClaim to be called
			// shortly (and in the right worker goroutine).
			// This speeds up binding of provisioned volumes - provisioner saves
			// only the new PV and it expects that next syncClaim will bind the
			// claim to it.
			ctrl.claimQueue.Add(claimToClaimKey(claim))
			return nil
		} else if claim.Spec.VolumeName == volume.Name {
			// Volume is bound to a claim properly, update status if necessary
			klog.V(4).Infof("synchronizing PersistentVolume[%s]: all is bound", volume.Name)
			if _, err = ctrl.updateVolumePhase(volume, v1.VolumeBound, ""); err != nil {
				// Nothing was saved; we will fall back into the same
				// condition in the next call to this method
				return err
			}
			return nil
		} else {
			// Volume is bound to a claim, but the claim is bound elsewhere
			if metav1.HasAnnotation(volume.ObjectMeta, pvutil.AnnDynamicallyProvisioned) && volume.Spec.PersistentVolumeReclaimPolicy == v1.PersistentVolumeReclaimDelete {
				// This volume was dynamically provisioned for this claim. The
				// claim got bound elsewhere, and thus this volume is not
				// needed. Delete it.
				// Mark the volume as Released for external deleters and to let
				// the user know. Don't overwrite existing Failed status!
				if volume.Status.Phase != v1.VolumeReleased && volume.Status.Phase != v1.VolumeFailed {
					// Also, log this only once:
					klog.V(2).Infof("dynamically volume %q is released and it will be deleted", volume.Name)
					if volume, err = ctrl.updateVolumePhase(volume, v1.VolumeReleased, ""); err != nil {
						// Nothing was saved; we will fall back into the same condition
						// in the next call to this method
						return err
					}
				}
				if err = ctrl.reclaimVolume(volume); err != nil {
					// Deletion failed, we will fall back into the same condition
					// in the next call to this method
					return err
				}
				return nil
			} else {
				// Volume is bound to a claim, but the claim is bound elsewhere
				// and it's not dynamically provisioned.
				if metav1.HasAnnotation(volume.ObjectMeta, pvutil.AnnBoundByController) {
					// This is part of the normal operation of the controller; the
					// controller tried to use this volume for a claim but the claim
					// was fulfilled by another volume. We did this; fix it.
					klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume is bound by controller to a claim that is bound to another volume, unbinding", volume.Name)
					if err = ctrl.unbindVolume(volume); err != nil {
						return err
					}
					return nil
				} else {
					// The PV must have been created with this ptr; leave it alone.
					klog.V(4).Infof("synchronizing PersistentVolume[%s]: volume is bound by user to a claim that is bound to another volume, waiting for the claim to get unbound", volume.Name)
					// This just updates the volume phase and clears
					// volume.Spec.ClaimRef.UID. It leaves the volume pre-bound
					// to the claim.
					if err = ctrl.unbindVolume(volume); err != nil {
						return err
					}
					return nil
				}
			}
		}
	}
}

```

上述代码比较长，主要逻辑如下：
首先判断PV的claimRef是否为空，如果为空更新PV为available状态。如果claimRef不为空，但是UID为空，说明PV绑定了PVC，但是PVC没有绑定PV，所以需要设置PV的状态为available。之后获取PV对应的PVC，为了防止本地缓存还未更新PVC，通过apiServer重新获取一次。

如果找到了对应的PVC，然后比较一下UID是否相等，如果不相等，说明不是对应绑定的PVC，可能PVC被删除了，更新PV的状态为released。这个时候会调用reclaimVolume方法，根据persistentVolumeReclaimPolicy进行相应的处理。

对claim校验之后，会继续查看claim.Spec.VolumeName是否为空，如果为空说明正在绑定中。

如果claim.Spec.VolumeName == volume.Name，说明volume与PVC绑定，更新pv状态为Bound。

剩下还有一部分逻辑是说PV绑定到PVC上，但是PVC被绑定到其他PV上，检查一下是否是dynamically provisioned自动生成的，如果是的话就释放这个PV；如果是手动创建的PV，那么调用unbindVolume进行解绑

上面是VolumeWoker的主要的工作逻辑。

下面看一下ClaimWorker的工作逻辑：
claimWorker也是通过不断的同步PVC，然后通过updateClaim调用syncClaim方法。

```go
// syncClaim is the main controller method to decide what to do with a claim.
// It's invoked by appropriate cache.Controller callbacks when a claim is
// created, updated or periodically synced. We do not differentiate between
// these events.
// For easier readability, it was split into syncUnboundClaim and syncBoundClaim
// methods.
func (ctrl *PersistentVolumeController) syncClaim(claim *v1.PersistentVolumeClaim) error {
    klog.V(4).Infof("synchronizing PersistentVolumeClaim[%s]: %s", claimToClaimKey(claim), getClaimStatusForLogging(claim))

    // Set correct "migrated-to" annotations on PVC and update in API server if
    // necessary
    newClaim, err := ctrl.updateClaimMigrationAnnotations(claim)
    if err != nil {
        // Nothing was saved; we will fall back into the same
        // condition in the next call to this method
        return err
    }
    claim = newClaim

    if !metav1.HasAnnotation(claim.ObjectMeta, pvutil.AnnBindCompleted) {
        return ctrl.syncUnboundClaim(claim)
    } else {
        return ctrl.syncBoundClaim(claim)
    }
}
```

syncClaim这个方法的主要逻辑是通过syncUnboundClaim和syncBoundClaim这两个方法进行绑定和解绑的操作。
syncUnboundClaim这个方法的主要逻辑分为两部分：一部分是当claim.Spec.VolumeName == "" ,代码如下：

```go
// syncUnboundClaim is the main controller method to decide what to do with an
// unbound claim.
func (ctrl *PersistentVolumeController) syncUnboundClaim(claim *v1.PersistentVolumeClaim) error {
    // This is a new PVC that has not completed binding
    // OBSERVATION: pvc is "Pending"
    //pending状态，没有完成绑定操作
    if claim.Spec.VolumeName == "" {
        // User did not care which PV they get.
        //是否是延迟绑定，这里涉及到了Local PV的延迟绑定操作
        delayBinding, err := pvutil.IsDelayBindingMode(claim, ctrl.classLister)
        if err != nil {
            return err
        }

        // [Unit test set 1]
        //根据claim的声明去找到合适的PV，这里涉及到延迟绑定，顺着这个方法一直看下去会看到会通过accessMode找到对应的PV，
        //然后再通过pvutil.FindMatchingVolume找到合适的PV，FindMatchingVolume会被PV controller and scheduler使用，
        //被scheduler使用就是因为涉及到了LocalPV的延迟绑定，调度时会综合考虑各种因素，选择最合适的节点运行pod
        volume, err := ctrl.volumes.findBestMatchForClaim(claim, delayBinding)
        if err != nil {
            klog.V(2).Infof("synchronizing unbound PersistentVolumeClaim[%s]: Error finding PV for claim: %v", claimToClaimKey(claim), err)
            return fmt.Errorf("error finding PV for claim %q: %w", claimToClaimKey(claim), err)
        }
        //如果没有volume可用
        if volume == nil {
            klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: no volume found", claimToClaimKey(claim))
            // No PV could be found
            // OBSERVATION: pvc is "Pending", will retry
            switch {
            case delayBinding && !pvutil.IsDelayBindingProvisioning(claim):
                if err = ctrl.emitEventForUnboundDelayBindingClaim(claim); err != nil {
                    return err
                }
                //根据对应的插件创建PV
            case storagehelpers.GetPersistentVolumeClaimClass(claim) != "":
                if err = ctrl.provisionClaim(claim); err != nil {
                    return err
                }
                return nil
            default:
                ctrl.eventRecorder.Event(claim, v1.EventTypeNormal, events.FailedBinding, "no persistent volumes available for this claim and no storage class is set")
            }

            // Mark the claim as Pending and try to find a match in the next
            // periodic syncClaim
            //下次循环再查找匹配的PV进行绑定
            if _, err = ctrl.updateClaimStatus(claim, v1.ClaimPending, nil); err != nil {
                return err
            }
            return nil
        } else /* pv != nil */ {
            // Found a PV for this claim
            // OBSERVATION: pvc is "Pending", pv is "Available"
            claimKey := claimToClaimKey(claim)
            klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume %q found: %s", claimKey, volume.Name, getVolumeStatusForLogging(volume))
            if err = ctrl.bind(volume, claim); err != nil {
                // On any error saving the volume or the claim, subsequent
                // syncClaim will finish the binding.
                // record count error for provision if exists
                // timestamp entry will remain in cache until a success binding has happened
                metrics.RecordMetric(claimKey, &ctrl.operationTimestamps, err)
                return err
            }
            // OBSERVATION: claim is "Bound", pv is "Bound"
            // if exists a timestamp entry in cache, record end to end provision latency and clean up cache
            // End of the provision + binding operation lifecycle, cache will be cleaned by "RecordMetric"
            // [Unit test 12-1, 12-2, 12-4]
            metrics.RecordMetric(claimKey, &ctrl.operationTimestamps, nil)
            return nil
        }
    }
```

主要处理逻辑是看是否能找到合适的PV，如果有就进行绑定。如果没有，检查PV是否是动态提供的，如果是则创建PV，然后设置PVC为pending，在下一轮的循环中进行检查绑定。
syncUnboundClaim方法的下半部分逻辑：

```awk
// syncUnboundClaim is the main controller method to decide what to do with an
// unbound claim.
func (ctrl *PersistentVolumeController) syncUnboundClaim(claim *v1.PersistentVolumeClaim) error {
else /* pvc.Spec.VolumeName != nil */ {
        // [Unit test set 2]
        // User asked for a specific PV.
        klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume %q requested", claimToClaimKey(claim), claim.Spec.VolumeName)
        //volume不为空，找到对应的PV
        obj, found, err := ctrl.volumes.store.GetByKey(claim.Spec.VolumeName)
        if err != nil {
            return err
        }
        //对应的PV不存在了，更新状态为Pending
        if !found {
            // User asked for a PV that does not exist.
            // OBSERVATION: pvc is "Pending"
            // Retry later.
            klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume %q requested and not found, will try again next time", claimToClaimKey(claim), claim.Spec.VolumeName)
            if _, err = ctrl.updateClaimStatus(claim, v1.ClaimPending, nil); err != nil {
                return err
            }
            return nil
        } else {
            volume, ok := obj.(*v1.PersistentVolume)
            if !ok {
                return fmt.Errorf("cannot convert object from volume cache to volume %q!?: %+v", claim.Spec.VolumeName, obj)
            }
            klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume %q requested and found: %s", claimToClaimKey(claim), claim.Spec.VolumeName, getVolumeStatusForLogging(volume))
            if volume.Spec.ClaimRef == nil { //PVC对应PV的Claim为空，调用bind方法进行绑定。
                // User asked for a PV that is not claimed
                // OBSERVATION: pvc is "Pending", pv is "Available"
                klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume is unbound, binding", claimToClaimKey(claim))
                if err = checkVolumeSatisfyClaim(volume, claim); err != nil {
                    klog.V(4).Infof("Can't bind the claim to volume %q: %v", volume.Name, err)
                    // send an event
                    msg := fmt.Sprintf("Cannot bind to requested volume %q: %s", volume.Name, err)
                    ctrl.eventRecorder.Event(claim, v1.EventTypeWarning, events.VolumeMismatch, msg)
                    // volume does not satisfy the requirements of the claim
                    if _, err = ctrl.updateClaimStatus(claim, v1.ClaimPending, nil); err != nil {
                        return err
                    }
                } else if err = ctrl.bind(volume, claim); err != nil {
                    // On any error saving the volume or the claim, subsequent
                    // syncClaim will finish the binding.
                    return err
                }
                // OBSERVATION: pvc is "Bound", pv is "Bound"
                return nil
                // 校验volume是是否已经绑定了别的PVC，如果没有的话，执行绑定
            } else if pvutil.IsVolumeBoundToClaim(volume, claim) {
                // User asked for a PV that is claimed by this PVC
                // OBSERVATION: pvc is "Pending", pv is "Bound"
                klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume already bound, finishing the binding", claimToClaimKey(claim))

                // Finish the volume binding by adding claim UID.
                if err = ctrl.bind(volume, claim); err != nil {
                    return err
                }
                // OBSERVATION: pvc is "Bound", pv is "Bound"
                return nil
            } else { //PVC声明的PV绑定了其他PVC，等待下次循环
                // User asked for a PV that is claimed by someone else
                // OBSERVATION: pvc is "Pending", pv is "Bound"
                if !metav1.HasAnnotation(claim.ObjectMeta, pvutil.AnnBoundByController) {
                    klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume already bound to different claim by user, will retry later", claimToClaimKey(claim))
                    claimMsg := fmt.Sprintf("volume %q already bound to a different claim.", volume.Name)
                    ctrl.eventRecorder.Event(claim, v1.EventTypeWarning, events.FailedBinding, claimMsg)
                    // User asked for a specific PV, retry later
                    if _, err = ctrl.updateClaimStatus(claim, v1.ClaimPending, nil); err != nil {
                        return err
                    }
                    return nil
                } else {
                    // This should never happen because someone had to remove
                    // AnnBindCompleted annotation on the claim.
                    klog.V(4).Infof("synchronizing unbound PersistentVolumeClaim[%s]: volume already bound to different claim %q by controller, THIS SHOULD NEVER HAPPEN", claimToClaimKey(claim), claimrefToClaimKey(volume.Spec.ClaimRef))
                    claimMsg := fmt.Sprintf("volume %q already bound to a different claim.", volume.Name)
                    ctrl.eventRecorder.Event(claim, v1.EventTypeWarning, events.FailedBinding, claimMsg)

                    return fmt.Errorf("invalid binding of claim %q to volume %q: volume already claimed by %q", claimToClaimKey(claim), claim.Spec.VolumeName, claimrefToClaimKey(volume.Spec.ClaimRef))
                }
            }
        }
    }
}
```

syncUnboundClaim下半部分逻辑主要是判断volume不为空，取出对应的PV进行绑定。如果claimRef不为空，校验一下是否已经是否绑定了别的PVC，如果没有的话，执行绑定。

syncClaim除了上面的syncUnboundClaim，还有syncBoundClaim方法，
syncBoundClaim方法主要是处理PVC和PV已经绑定的各种异常情况。代码不贴了。