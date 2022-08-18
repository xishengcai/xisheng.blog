# 项目使用手册

1. 开发设备安装 [node](https://nodejs.org/zh-cn/) 环境。
2. 将该工程根目录下的 `package.json`、`commitlint.config.js`、`.npmrc`、`.commit-template`（可选）、`.cz-config.js`（可选）文件拷贝到需要 commitlint 支持的项目 B 根目录。
3. 在项目 B 根目录的终端运行 `npm install`。
4. 在项目 B 的.gitignore 增加 `node_modules` 及 `/package-lock.json` 两条忽略路径。
5. 执行命令 `npm run config:commit-template` 设置 commit 提示模板（可选，需要拷贝 `.commit-template` 文件）。
6. 执行 `npm run commit` 可进行终端交互提示提交（可选，需要拷贝 `.cz-config.js` 文件）。

在执行完上面 1~4 的步骤后，每次 `git commit` 提交将会触发 commit message 规范校验。具体规范如下：

# LStack 前端代码提交规范

通过前面的介绍，我们了解了规范的代码提交不仅能很好地提升项目的可维护性，还可自动格式化生成版本日志。在了解了 [Angular 团队的规范](https://github.com/angular/angular.js/blob/master/DEVELOPERS.md#-git-commit-guidelines) 和 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0-beta.4/) 之后，LStack 前端在其基础上形成了适用团队的规范并形成规格校验 [插件](http://npm.lstack.bye913.com/-/web/detail/@cli/commitlint-plugin-lstack) 和 [配置](http://npm.lstack.bye913.com/-/web/detail/@cli/commitlint-config-lstack) 。具体如下：

## Message 格式

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

基本结构分为标题行（Header）、主题内容（Body）和页脚（Footer）三个部分，彼此之间使用空行分割。而不管是哪一个部分，他们中任何一行都不得超过 100 个字符，这是为了避免自动换行影响美观。

### Header

标题行，是每次提交必填的部分，不要超过一行，用于描述本次主要修改的类别（type）、范围（scope）以及主题（subject）。

#### type

本次提交的类别，必填，其中 fix 和 feat 是主要的 type，分别代表问题的修复和新功能的增加，我们会根据 fix 和 feat 类别的提交自动生成 changelog 。

类别必须是下面其中一个：

- import: 限定类别，当源码引入开源库，希望作为 CI 的特使标记时，必须使用该类别，且本次提交必须不涉及其他类别，对应 action 只能为`导入`。
- build: 限定类别，对构建系统或者相关外部依赖项进行了修改（比如: gulp, broccoli, npm），必须使用该类别，且本次提交必须不涉及其他类别。
- ci: 限定类别，涉及 CI 配置文件或脚本修改的变动，必须使用该类别，且本次提交必须不涉及其他类别。
- feat: 主类别，增加了新的功能特征，对应 action 只能为 `添加`，除限定类别外，当一次提交涉及主类别与其他多种类别时，取主类别。
- fix: 主类别，修复 bug，bug 定义基线为上一个版本（即线上 bug，需要注意的是 ST 及 SIT 等由当前版本新功能引入的缺陷请使用 st 或 sit 类别），否则不要选择该类型，对应 action 只能为 `修复`。
- st: 解决 ST 单子，仅限 release 分支，对应 action 只能为`修复`，该类别必须单独提交。如果单子是上版本引入的（线上 bug），必须选择 fix 类别。
- sit: 解决 SIT 单子，仅限 release 分支，对应 action 只能为`修复`，该类别必须单独提交，如果单子是上版本引入的，必须选择 fix 类别。
- style: 不影响代码含义的风格修改，比如空格、格式化、缺失的分号等，对应 action 只能为`调整`，该类别只能单独提交。
- test: 新增或修改已有测试用例，该类别只能单独提交。
- docs: 对文档类文件进行了修改，该类别只能单独提交。
- revert: 回滚 commit 操作，对应 scope 为空，subject 为被回滚 commit message 的 完整 header，该类别只能单独提交。
- pref: 提高性能的代码更改，对应 action 只能为`优化`。
- refactor: 既不是修复 bug 也不是添加特征的代码重构。
- version: 发布版本，一般由脚本自动化发布，对应 action 只能为`发布`。

#### scope

本次提交影响的范围，必填。scope 依据项目而定，例如在业务项目中可以依据菜单或者功能模块划分，如果是组件库开发，则可以依据组件划分。

格式为项目名/模块名，例如：node-pc/common rrd-h5/activity，而 we-sdk 不需指定模块名。如果一次 commit 修改多个模块，必须拆分成多次 commit，以便更好追踪和维护，即不允许跨 scope 进行提交。

LStack 前端团队以 [monorepo](https://www.perforce.com/blog/vcs/what-monorepo) 工程的 package 作为 scope，通过脚本自动获取，无需手动维护。需要注意的是，与工程相关的提交我们约定 scope 为 root。

#### subject

对于本次提交修改内容的简要描述，必填，以第一人称使用现在时，不以大写字母开头，不以`.`或`。`结尾，LStack 在社区的基础上将 subject 分为 action 和 content 两部分，两者间以空格相隔。

action：描述 subject 的具体动作，可选枚举为【'添加', '完善', '修复', '解决', '删除', '禁用', '修改', '调整', '优化', '重构', '发布', '合并', '导入'】。

### Body

主题内容，非必须，描述为什么修改, 做了什么样的修改, 以及开发的思路等等，可以由多行组成。

### Footer

页脚注释，在正文结束的一个空行之后，可以编写一行或多行脚注。

脚注必须包含关于提交的元信息，例如：关联的合并请求、Reviewer、破坏性变更，每条元信息一行。

破坏性变更必须标示在正文区域最开始处，或脚注区域中某一行的开始。一个破坏性变更必须包含大写的文本 `BREAKING CHANGE`，后面紧跟冒号和空格。

在 BREAKING CHANGE: 之后必须提供描述，以描述对 API 的变更。

列举本次提交 Closes 对应的 Tapd 缺陷 ID 或 issue 编号（存在则必填，即 st、sit、fix 类别提交必填）当该提交同时关了多个 issues 时，以','加空格进行分隔，如:`Closes #33, #34`。注意：当关闭的是 tapd 缺陷单子时，要求一次提交仅能 Closes 一个单子，如：`Closes #1000001`。

## 提交原则（强制）

1. type、scope 及 subject 皆为必填项。需要注意的是 revert 类别的提交，scope 需且必须必须为空，其 subject 为被 revert commit 的 Header。
2. 不允许跨 scope 提交，如：不允许在一次提交中同时提交 lcs 和 lcr 两个 scope 的文件。
3. 当该次提交的 type 为限定类别（import、build、ci）时，必须原子性单独提交。
4. 当该次提交的 type 同时包含主类别（feat、fix）与其他类别，选取主类别的 type。
5. break changes 指明是否产生了破坏性修改，涉及 break changes 的改动必须指明该项，类似版本升级、接口参数减少、接口删除、迁移等。
6. affect issues 指明是否影响了某个问题。当提交类别为 st、sit、fix 时，footer 中必须填写。例如我们使用 TAPD 时，需要填写其影响的 TAPD_ID：Closes #1000001 。
7. 单次提交可以 Closes 多个 issue，但是如果关闭的是 TAPD 的缺陷时，单次提交只能 Closes 一个 TAPD 缺陷 ID。如果是重复的问题单，应该合并问题单。
8. 提交的相关文件必须与 scope 相对应，如：不允许在修改 lcs bug 时提交为 lcr 的 scope。
9. subject 无需标点结尾。
10. 标题行（Header）、主题内容（Body）和页脚（Footer）三个部分必须空一行（如果存在）。
11. 除 revert 类别的提交外，标题行（Header）长度不能超过 72。
12. 提交标题简要描述 subject 应该以指定动词中的 action 起头（只能为中文现在时），提交标题简要描述 subject 动词 action 后需且仅需添加一个空格。action 取自枚举 ['添加', '完善', '修复', '解决', '删除', '禁用', '修改', '调整', '优化', '重构', '发布', '合并', '导入']，作为 code review 的依据。
13. 如果提交 footer 包含不兼容变更 `BREAKING CHANGE`，需要在类型/作用域前缀之后，':'之前，附加'!'字符，以进一步提醒注意破坏性变更。反之不需要。
14. message 文案书写规范建议参考[这里](https://github.com/ruanyf/document-style-guide) 。中英文字符间必须加空格。

```
action 与 type 的对应规则：

1、当 type 为 'import' 时，action 必须为 '导入'。
2、当 type 为 'feat' 时，action 必须为 '添加'。
3、当 type 为 'version' 时，action 必须为 '发布'，反之亦然。
4、当 type 为 'pref' 时，action 必须为 '优化'。
5、当 type 为 'style' 时，action 必须为 '调整'。
6、当 type 为 [fix, st, sit] 之一时，action 必须为 '修复'，反之亦然。
```

## 提交规范（建议）

1. body 用于填写详细描述，主要描述改动之前的情况及修改动机，对于小的修改不作要求，但是重大需求、更新等须添加 body 来作说明。
2. 根据不同的 git 工作流限定问题单修复分支，LStack 前端使用的是 Git Flow，及 si、sit 类别提交仅限于 release 分支，相应的 release 只能进行 fix、st、sit 类型的提交。。
3. build 涉及的依赖变动理解为更新版本号，但涉及依赖的增删必须跟随相关功能变动，由功能或业务触发，对应 type 不为 build。

## commit message 示例：

包含不兼容的变更 `BREAKING CHANGE` 的提交：

```
refactor(lcs)!: 修改 命名空间结构体，以 yaml 资源形式定义

修改命名空间的结构体，替换原表单形式，用 yaml 资源的形式取代。

BREAKING CHANGE: 本次修改涉及 xxx 文件，具体改动内容为 xxx，影响模块 xxx，需要进行 xxx 处理以兼容本次修改。
```

只包含 Header 的简单提交：

```
version(stylelint-config-lstack): 发布 v0.1.0
```

回滚某次提交的提交：

```
revert: version(stylelint-config-lstack): 发布 v0.1.0

被 revert commit 为 #d21a542930e92f12c8ee9da5f378e66958f43875。
```

修复某个 sit 缺陷的提交

```
sit(ams): 修复 应用管理 HPA 没有检测 metrics-server 安装

问题分析：粗心导致。
问题解决：当拖拽自动扩缩时检测是否安装 metrics-server 插件。

Closes #1002859
```

更多社区例子可以参考：[这里](https://docs.google.com/document/d/1QrDFcIiPjSLDn3EL15IJygNPiHORgU1_OOAqWjiDU5Y/edit#)

## 常见问题

在规范提交时可能会遇到一些问题，以下是一些相关建议：

### 问题一：当我功能开发到一半，需要改 bug。

解决建议：

1. 啥也不干，在提交时分 feat 和 fix 两次进行提交。
2. 当前代码先暂存 `git stash`，改完 bug 提交后在推出来 `git stash pop` 继续开发新功能。
3. 先临时提交一次半成品功能，改完 bug 提交后，再继续提交后续补充的代码。再本地将两次半成品 `feat` 类别提交合并 `git rebase -i xx`。（推荐）

### 问题二：当我功能开发完本地提交了一次，还没推到库上多人协作分支上，突然想起有些细节要补充。

解决建议：

1. 补充一个 refactor 类别的提交。
2. 补完代码后 `git add xx` && `git commit --amend` 对最后一次提交进行编辑修改。（推荐）
3. 在建议 1 的基础上对两次提交进行合并为一次完成的 feat 类别提交 `git rebase -i`。
4. 直接 `git rebase -i xx` 到指定 commit 进行修改。改完后 `git add xx` && `git rebase --continue`

### 问题三：刚刚开发新功能接到一个 bug 单子，忘了切分支，直接在开发分支上进行了提交。

解决建议：

1. `git cherry-pick xx1` 将 commit 捡到 release 分支上，然后 dev 分支上 `git reset HEAD~1`，删除 reset 后的代码。
2. `git cherry-pick xx1` 将 commit 捡到 release 分支上，然后 dev 分支上 `git rebase -i xx2` 删除被捡 commit。（推荐）

**注意：需要强调的是，所有涉及到变基的 git 操作仅限于本地分支或库上个人分支。与他人协作的线上分支严禁使用 `git push -f`。如果真的必须这么做，请知会相关项目负责人进行操作。**