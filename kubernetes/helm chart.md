# Helm charts




## DirectoryStruct
```
apiVersion: The chart API version, always "v1" (required)
name: The name of the chart (required)
version: A SemVer 2 version (required)
kubeVersion: A SemVer range of compatible Kubernetes versions (optional)
description: A single-sentence description of this project (optional)
keywords:
  - A list of keywords about this project (optional)
home: The URL of this project's home page (optional)
sources:
  - A list of URLs to source code for this project (optional)
maintainers: # (optional)
  - name: The maintainer's name (required for each maintainer)
    email: The maintainer's email (optional for each maintainer)
    url: A URL for the maintainer (optional for each maintainer)
engine: gotpl # The name of the template engine (optional, defaults to gotpl)
icon: A URL to an SVG or PNG image to be used as an icon (optional).
appVersion: The version of the app that this contains (optional). This needn't be SemVer.
deprecated: Whether this chart is deprecated (optional, boolean)
tillerVersion: The version of Tiller that this chart requires. This should be expressed as a SemVer range: ">2.0.0" (optional)
```

## VersionController
每个chart都必须有个版本号。命名必须符合[semver2](https://semver.org/lang/zh-CN/),简而言之就是[主].[次].[修]

许多 Helm 工具都使用 Chart.yaml 的 version 字段，其中包括 CLI 和 Tiller 服务。在生成包时，helm package 命令将使用它在 Chart.yaml 中的版本名作为包名。系统假定 chart 包名称中的版本号与 Chart.yaml 中的版本号相匹配。不符合这个情况会导致错误。

请注意，appVersion 字段与 version 字段无关。这是一种指定应用程序版本的方法。例如，drupal chart 可能有一个 appVersion: 8.2.1，表示 chart 中包含的 Drupal 版本（默认情况下）是 8.2.1。该字段是信息标识，对 chart 版本没有影响。

**appVersion 字段**

请注意，appVersion 字段与 version 字段无关。这是一种指定应用程序版本的方法。例如，drupal chart 可能有一个 appVersion: 8.2.1，表示 chart 中包含的 Drupal 版本（默认情况下）是 8.2.1。该字段是信息标识，对 chart 版本没有影响。

## 依赖关系
在 Helm 中，一个 chart 可能依赖于任何数量的其他 chart。这些依赖关系可以通过 requirements.yaml 文件动态链接或引入 charts/ 目录并手动管理。

虽然有一些团队需要手动管理依赖关系的优势，但声明依赖关系的首选方法是使用 chart 内部的 requirements.yaml 文件。

**注意：** 传统 Helm 的 Chart.yaml dependencies: 部分字段已被完全删除弃用。

**用 requirements.yaml 来管理依赖关系**

requirements.yaml 文件是列出 chart 的依赖关系的简单文件。
```
dependencies:
  - name: apache
    version: 1.2.3
    repository: http://example.com/charts
  - name: mysql
    version: 3.2.1
    repository: http://another.example.com/charts
```

**requirements.yaml 中的 alias 字段**

可以通过给相同charts不同版本的依赖包起别名
```
# parentchart/requirements.yaml
dependencies:
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    alias: new-subchart-1
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    alias: new-subchart-2
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
```