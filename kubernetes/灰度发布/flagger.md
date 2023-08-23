

## 简介

 [Flagger](https://github.com/weaveworks/flagger)是一个能使运行在k8s体系上的应用发布流程全自动(无人参与)的工具, 它能减少发布的人为关注时间, 并且在发布过程中能自动识别一些风险(例如:RT,成功率,自定义metrics)并回滚.



![arch](https://intranetproxy.alipay.com/skylark/lark/0/2020/png/10296/1583644556222-eeff1c1d-8096-4dbc-9a3b-7ec6626401e2.png?x-oss-process=image/resize,w_1412)



简单介绍下上图含义:
• primary service: 服务稳定版本. 可以理解为已发布在线的服务
• canary service: 即将发布的新版本服务.
• Ingress: 服务网关.
• Flagger: 会通过flagger spec(下面会介绍), 以ingress/service mesh的规范来调整primary和canary的流量策略.以此来达到A/B testing, blue/green, canary(金丝雀)发布效果. 在调整流量过程中, 根据[prometheus](https://prometheus.io/docs/introduction/overview/)采集的各项指标(RT,成功率等)来决策是否回滚发布或者继续调整流量比例。在此过程中,用户可以自定义是否人工干预,审核,收到通知等.



1. User create canary， ingress(podInfo)

2. flagger initialize

   1. create podinfo-svc
   2. create podinfo-svc-canary
   3. create podinfo-svc-primary
   4. create deployment podinfo-primary

3. flagger create ingress podinfo-canary

4. flagger modify ingress podinfo-canary annotation weight

   

```go
	// create primary workload
	err = canaryController.Initialize(cd)
	if err != nil {
		c.recordEventWarningf(cd, "%v", err)
		return
	}

	// change the apex service pod selector to primary
	if err := kubeRouter.Reconcile(cd); err != nil {
		c.recordEventWarningf(cd, "%v", err)
		return
	}
```





```go
// Initialize creates or updates the primary and canary services to prepare for the canary release process targeted on the K8s service
func (c *ServiceController) Initialize(cd *flaggerv1.Canary) (err error) {
	targetName := cd.Spec.TargetRef.Name
	primaryName := fmt.Sprintf("%s-primary", targetName)
	canaryName := fmt.Sprintf("%s-canary", targetName)

	svc, err := c.kubeClient.CoreV1().Services(cd.Namespace).Get(context.TODO(), targetName, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("service %s.%s get query error: %w", primaryName, cd.Namespace, err)
	}

	if err = c.reconcileCanaryService(cd, canaryName, svc); err != nil {
		return fmt.Errorf("reconcileCanaryService failed: %w", err)
	}

	if err = c.reconcilePrimaryService(cd, primaryName, svc); err != nil {
		return fmt.Errorf("reconcilePrimaryService failed: %w", err)
	}

	return nil
}
```





```
// Reconcile creates or updates the main service
func (c *KubernetesDefaultRouter) Reconcile(canary *flaggerv1.Canary) error {
	apexName, _, _ := canary.GetServiceNames()

	// main svc
	err := c.reconcileService(canary, apexName, fmt.Sprintf("%s-primary", c.labelValue), canary.Spec.Service.Apex)
	if err != nil {
		return fmt.Errorf("reconcileService failed: %w", err)
	}

	return nil
}
```



```go
func (c *KubernetesDefaultRouter) reconcileService(canary *flaggerv1.Canary, name string, podSelector string, metadata *flaggerv1.CustomMetadata) error {
	portName := canary.Spec.Service.PortName
	if portName == "" {
		portName = "http"
	}

	targetPort := intstr.IntOrString{
		Type:   intstr.Int,
		IntVal: canary.Spec.Service.Port,
	}

	if canary.Spec.Service.TargetPort.String() != "0" {
		targetPort = canary.Spec.Service.TargetPort
	}

	// set pod selector and apex port
	svcSpec := corev1.ServiceSpec{
		Type:     corev1.ServiceTypeClusterIP,
		Selector: map[string]string{c.labelSelector: podSelector},
		Ports: []corev1.ServicePort{
			{
				Name:       portName,
				Protocol:   corev1.ProtocolTCP,
				Port:       canary.Spec.Service.Port,
				TargetPort: targetPort,
			},
		},
	}

	// set additional ports
	for n, p := range c.ports {
		cp := corev1.ServicePort{
			Name:     n,
			Protocol: corev1.ProtocolTCP,
			Port:     p,
			TargetPort: intstr.IntOrString{
				Type:   intstr.Int,
				IntVal: p,
			},
		}

		svcSpec.Ports = append(svcSpec.Ports, cp)
	}

	if metadata == nil {
		metadata = &flaggerv1.CustomMetadata{}
	}

	if metadata.Labels == nil {
		metadata.Labels = make(map[string]string)
	}
	metadata.Labels[c.labelSelector] = name

	if metadata.Annotations == nil {
		metadata.Annotations = make(map[string]string)
	}

	// create service if it doesn't exists
	svc, err := c.kubeClient.CoreV1().Services(canary.Namespace).Get(context.TODO(), name, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		svc = &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:        name,
				Namespace:   canary.Namespace,
				Labels:      metadata.Labels,
				Annotations: filterMetadata(metadata.Annotations),
				OwnerReferences: []metav1.OwnerReference{
					*metav1.NewControllerRef(canary, schema.GroupVersionKind{
						Group:   flaggerv1.SchemeGroupVersion.Group,
						Version: flaggerv1.SchemeGroupVersion.Version,
						Kind:    flaggerv1.CanaryKind,
					}),
				},
			},
			Spec: svcSpec,
		}

		_, err := c.kubeClient.CoreV1().Services(canary.Namespace).Create(context.TODO(), svc, metav1.CreateOptions{})
		if err != nil {
			return fmt.Errorf("service %s.%s create error: %w", svc.Name, canary.Namespace, err)
		}

		c.logger.With("canary", fmt.Sprintf("%s.%s", canary.Name, canary.Namespace)).
			Infof("Service %s.%s created", svc.GetName(), canary.Namespace)
		return nil
	} else if err != nil {
		return fmt.Errorf("service %s get query error: %w", name, err)
	}

	// update existing service pod selector and ports
	if svc != nil {
		sortPorts := func(a, b interface{}) bool {
			return a.(corev1.ServicePort).Port < b.(corev1.ServicePort).Port
		}

		// copy node ports from existing service
		for _, port := range svc.Spec.Ports {
			for i, servicePort := range svcSpec.Ports {
				if port.Name == servicePort.Name && port.NodePort > 0 {
					svcSpec.Ports[i].NodePort = port.NodePort
					break
				}
			}
		}

		updateService := false
		svcClone := svc.DeepCopy()

		portsDiff := cmp.Diff(svcSpec.Ports, svc.Spec.Ports, cmpopts.SortSlices(sortPorts))
		selectorsDiff := cmp.Diff(svcSpec.Selector, svc.Spec.Selector)
		if portsDiff != "" || selectorsDiff != "" {
			svcClone.Spec.Ports = svcSpec.Ports
			svcClone.Spec.Selector = svcSpec.Selector
			updateService = true
		}

		// update annotations and labels only if the service has been created by Flagger
		if _, owned := c.isOwnedByCanary(svc, canary.Name); owned {
			if svc.ObjectMeta.Annotations == nil {
				svc.ObjectMeta.Annotations = make(map[string]string)
			}
			if diff := cmp.Diff(filterMetadata(metadata.Annotations), svc.ObjectMeta.Annotations); diff != "" {
				svcClone.ObjectMeta.Annotations = filterMetadata(metadata.Annotations)
				updateService = true
			}
			if diff := cmp.Diff(metadata.Labels, svc.ObjectMeta.Labels); diff != "" {
				svcClone.ObjectMeta.Labels = metadata.Labels
				updateService = true
			}
		}

		if updateService {
			if svcClone.ObjectMeta.Annotations == nil {
				svcClone.ObjectMeta.Annotations = make(map[string]string)
			}
			svcClone.ObjectMeta.Annotations = filterMetadata(svcClone.ObjectMeta.Annotations)
			_, err = c.kubeClient.CoreV1().Services(canary.Namespace).Update(context.TODO(), svcClone, metav1.UpdateOptions{})
			if err != nil {
				return fmt.Errorf("service %s update error: %w", name, err)
			}
			c.logger.With("canary", fmt.Sprintf("%s.%s", canary.Name, canary.Namespace)).
				Infof("Service %s updated", svc.GetName())
		}
	}

	return nil
}

```





