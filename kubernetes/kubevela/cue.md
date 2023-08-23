# CUE 是一种开源数据约束语言，旨在简化涉及定义和使用数据的任务(The CUE Data Constraint Language)

<!--toc-->

## CUE 背景介绍

BCL 全名 Borg Configuration Language，是 Google 内部基于 GCL (Generic Configuration Language) 在 Borg 场景的实践。用户通过 BCL 描述对 Borg 的使用需求，通过基于 BCL 的抽象省去对 Borg 复杂配置细节的感知提高单位效率，通过工程化手段满足可抽象、可复用、可测试的协作方式提高团队效率和稳定性，并在其上建立了相应的生态平台，作为 Borg 生态的重要抽象层在 Google 内部服务了超过 10 年，帮助 Google 内部数万开发者更好的使用 Infra。遗憾的是 BCL 并未开源，无法对 BCL 的实现、使用、生态做更多深入的解析。

CUE 是一种服务于云化配置的强类型配置语言，由 Go team 成员 Marcel van Lohiuzen 结合 BCL 及多种其他语言研发并开源，可以说是 BCL 思路的开源版实现。

CUE 延续了 JSON 超集的思路，额外提供了丰富的类型、表达式、import 语句等常用能力；与 JSONNET 不同，CUE 不支持自定义 function，支持基于 typed feature structure 思路的外置 schema，并通过显式的合一化、分离化操作支持类型和数据的融合，但这样的设定及外置类型推导同样增加了理解难度和编写复杂性。

CUE 项目完全由 Golang 编写，同时背靠 Golang，允许通过 “import” 引入 CUE 提供的必需能力协助用户完成如 encoding, strings, math 等配置编写常用功能。可以说 CUE 既属于 JSON 系的模板语言，同时也带有了很多 Configuration Language 的思考，提供了良好的样本，无论是其语言设计思路，还是基于成熟高级编程语言引入能力的工程方式都值得深入学习，但由于其部分设定过于晦涩也使得其难于理解，上手难度高。目前 CUE 在部分开源项目中使用，如在 ISTIO 中有小规模使用。

BCL 在 Google 内部虽然被广泛推广使用，但由于其语言特性定义不清晰、研发测试支持较差、新语言学习成本等问题在一线受到较多的吐槽。CUE 试图解决其中的语言特性问题，并提供了较为清晰的 spec 帮助使用者理解语言定义，但在研发测试支持、新语言理解难度、上手成本上没有较大的提升，使用者仍然无法较好的编写、测试，不能容易的 debug；语言自创的 schema 模板及大量私货写法对于使用者来说仍然意味着学习一种新的难写的语言，受众需要足够 geek 且有足够的耐心来让自己成为专家。归根到底模板定义区别于编程语言的一个重点就在于完善可编程性的缺失，这使得编写总会遇到这样那样的麻烦。



## The CUE Data Constraint Language

*Configure, Unify, Execute*

CUE is an open source data constraint language which aims to simplify tasks involving defining and using data.

It is a superset of JSON, allowing users familiar with JSON to get started quickly.

### What is it for?

You can use CUE to

- define a detailed validation schema for your data (manually or automatically from data)
- reduce boilerplate in your data (manually or automatically from schema)
- extract a schema from code
- generate type definitions and validation code
- merge JSON in a principled way
- define and run declarative scripts



### How?

CUE merges the notion of schema and data. The same CUE definition can simultaneously be used for validating data and act as a template to reduce boilerplate. Schema definition is enriched with fine-grained value definitions and default values. At the same time, data can be simplified by removing values implied by such detailed definitions. The merging of these two concepts enables many tasks to be handled in a principled way.

Constraints provide a simple and well-defined, yet powerful, alternative to inheritance, a common source of complexity with configuration languages.



### CUE Scripting

The CUE scripting layer defines declarative scripting, expressed in CUE, on top of data. This solves three problems: working around the closedness of CUE definitions (we say CUE is hermetic), providing an easy way to share common scripts and workflows for using data, and giving CUE the knowledge of how data is used to optimize validation.

There are many tools that interpret data or use a specialized language for a specific domain (Kustomize, Ksonnet). This solves dealing with data on one level, but the problem it solves may repeat itself at a higher level when integrating other systems in a workflow. CUE scripting is generic and allows users to define any workflow.



### Tooling

CUE is designed for automation. Some aspects of this are:

- convert existing YAML and JSON
- automatically simplify configurations
- rich APIs designed for automated tooling
- formatter
- arbitrary-precision arithmetic
- generate CUE templates from source code
- generate source code from CUE definitions (TODO)

### Download and Install

#### Install using Homebrew

Using [Homebrew](https://links.jianshu.com/go?to=https%3A%2F%2Fbrew.sh), you can install using the CUE Homebrew tap:

```
brew install cuelang/tap/cue
```

#### Install From Source

If you already have Go installed, the short version is:

```javascript
go get -u cuelang.org/go/cmd/cue
```

This will install the `cue` command line tool.

For more details see [Installing CUE](https://links.jianshu.com/go?to=.%2Fdoc%2Finstall.md).

### Learning CUE

The fastest way to learn the basics is to follow the [tutorial on basic language constructs](https://links.jianshu.com/go?to=.%2Fdoc%2Ftutorial%2Fbasics%2FReadme.md).

A more elaborate tutorial demonstrating of how to convert and restructure an existing set of Kubernetes configurations is available in [written form](https://links.jianshu.com/go?to=.%2Fdoc%2Ftutorial%2Fkubernetes%2FREADME.md).

### References

- [Language Specification](https://links.jianshu.com/go?to=.%2Fdoc%2Fref%2Fspec.md): official CUE Language specification.
- [API](https://links.jianshu.com/go?to=https%3A%2F%2Fgodoc.org%2Fcuelang.org%2Fgo%2Fcue): the API on godoc.org
- [Builtin packages](https://links.jianshu.com/go?to=https%3A%2F%2Fgodoc.org%2Fcuelang.org%2Fgo%2Fpkg): builtins available from CUE programs
- [`cue` Command line reference](https://links.jianshu.com/go?to=.%2Fdoc%2Fcmd%2Fcue.md): the `cue` command

### Contributing

Our canonical Git repository is located at [https://cue.googlesource.com](https://links.jianshu.com/go?to=https%3A%2F%2Fcue.googlesource.com).

To contribute, please read the [Contribution Guide](https://links.jianshu.com/go?to=.%2Fdoc%2Fcontribute.md).

To report issues or make a feature request, use the [issue tracker](https://links.jianshu.com/go?to=https%3A%2F%2Fgithub.com%2Fcuelang%2Fcue%2Fissues).

Changes can be contributed using Gerrit or Github pull requests.

### Contact

You can get in touch with the cuelang community in the following ways:

- Chat with us on our [Slack workspace](https://links.jianshu.com/go?to=https%3A%2F%2Fjoin.slack.com%2Ft%2Fcuelang%2Fshared_invite%2FenQtNzQwODc3NzYzNTA0LTAxNWQwZGU2YWFiOWFiOWQ4MjVjNGQ2ZTNlMmIxODc4MDVjMDg5YmIyOTMyMjQ2MTkzMTU5ZjA1OGE0OGE1NmE).

------

Unless otherwise noted, the CUE source files are distributed under the Apache 2.0 license found in the LICENSE file.

This is not an officially supported Google product.



参考资料：

-  [https://github.com/cuelang/cue/blob/master/README.md](https://links.jianshu.com/go?to=https%3A%2F%2Fgithub.com%2Fcuelang%2Fcue%2Fblob%2Fmaster%2FREADME.md) [https://python.ctolib.com/cuelang-cue.html](https://links.jianshu.com/go?to=https%3A%2F%2Fpython.ctolib.com%2Fcuelang-cue.html)
- https://links.jianshu.com/go?to=https%3A%2F%2Fgithub.com%2Fcuelang%2Fcue%2Fblob%2Fmaster%2Fdoc%2Fref%2Fspec.md
- [The CUE Language Specification]([https://github.com/cuelang/cue/blob/master/doc/ref/spec.md)