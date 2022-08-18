[toc]

# 1-start

## 搭建开发环境

要想搭建开发环境，请遵循[搭建本地环境](https://angular.cn/guide/setup-local)中的步骤进行操作。

## 创建新的工作区和一个初始应用

Angular 的[工作区](https://angular.cn/guide/glossary#workspace)就是你开发应用所在的上下文环境。一个工作区包含一个或多个[项目](https://angular.cn/guide/glossary#project)所需的文件。 每个项目都是一组由应用、库或端到端（e2e）测试组成的文件集合。 在本教程中，你将创建一个新的工作区。

要想创建一个新的工作区和一个初始应用项目，需要：

1. 确保你现在没有位于 Angular 工作区的文件夹中。例如，如果你之前已经创建过 "快速上手" 工作区，请回到其父目录中。
2. 运行 CLI 命令 `ng new`，空间名请使用 `angular-tour-of-heroes`，如下所示：

```
ng new angular-tour-of-heroes
```

3. `ng new` 命令会提示你输入要在初始应用项目中包含哪些特性，请按 Enter 或 Return 键接受其默认值。



## 启动应用服务器

进入工作区目录，并启动这个应用。

```
cd angular-tour-of-heroes
ng serve --open
```



>`ng serve` 命令会构建本应用、启动开发服务器、监听源文件，并且当那些文件发生变化时重新构建本应用。

> `--open` 标志会打开浏览器，并访问 `http://localhost:4200/`。



## Angular 组件

你所看到的这个应用就是一个外壳。这个外壳是被一个名叫AppComponent的Angular组件控制的。

*组件*是 Angular 应用中的基本构造块。 它们在屏幕上显示数据，监听用户输入，并且根据这些输入执行相应的动作。





