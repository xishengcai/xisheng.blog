# kustomize

kustomize lets you customize raw, template-free YAML files for multiple purpose, leaving the original YAML untouched and unabl as is.

Kustomize targets tubernetes; it understands and can patch kubernetes style API objects. It's like make, in that what it does is declared in a file, and it's like sed, in that it emits text.



Usage:

### 1) Make a [kustomization](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#kustomization) file

In some directory containing your YAML [resource](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#resource) files (deployments, services, configmaps, etc.), create a [kustomization](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#kustomization) file.

This file should declare those resources, and any customization to apply to them, e.g. *add a common label*.

1) Make a customizeation file

   ![](https://github.com/kubernetes-sigs/kustomize/raw/master/docs/images/base.jpg)

   

File Struct

```
~/someApp
├── deployment.yaml
├── kustomization.yaml
└── service.yaml
```

The resources in this directory could be a fork of someone else's configuration. If so, you can easily rebase from the source material to capture improvements, because you don't modify the resources directly.



Generate customized YAML with:

```
kustomize build ~/someApp
```



The YAML can be directly [applied](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#apply) to a cluster:

```
kustomize build ~/someApp | kubectl apply -f -
```



### 2) Create [variants](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#variant) using [overlays](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#overlay)

Manage traditional [variants](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#variant) of a configuration - like *development*, *staging* and *production* - using [overlays](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#overlay) that modify a common [base](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#base).

![](https://github.com/kubernetes-sigs/kustomize/raw/master/docs/images/overlay.jpg)

File struct:

```
~/someApp
├── base
│   ├── deployment.yaml
│   ├── kustomization.yaml
│   └── service.yaml
└── overlays
    ├── development
    │   ├── cpu_count.yaml
    │   ├── kustomization.yaml
    │   └── replica_count.yaml
    └── production
        ├── cpu_count.yaml
        ├── kustomization.yaml
        └── replica_count.yaml
```

Take the work from step (1) above, move it into a `someApp` subdirectory called `base`, then place overlays in a sibling directory.

An overlay is just another kustomization, referring to the base, and referring to patches to apply to that base.

This arrangement makes it easy to manage your configuration with `git`. The base could have files from an upstream repository managed by someone else. The overlays could be in a repository you own. Arranging the repo clones as siblings on disk avoids the need for git submodules (though that works fine, if you are a submodule fan).

Generate YAML with

```
kustomize build ~/someApp/overlays/production
```



The YAML can be directly [applied](https://kubernetes-sigs.github.io/kustomize/api-reference/glossary#apply) to a cluster:

```
kustomize build ~/someApp/overlays/production | kubectl apply -f -
```

