[toc]

# 2-component

应用程序现在有了基本的标题。 接下来你要创建一个新的组件来显示英雄信息并且把这个组件放到应用程序的外壳里去。

## 创建英雄列表组件

使用 Angular CLI 创建一个名为 `heroes` 的新组件。

```bash
ng generate component heroes
```



CLI 创建了一个新的文件夹 `src/app/heroes/`，并生成了 `HeroesComponent` 的四个文件。

`HeroesComponent` 的类文件如下：

```typescript
import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'app-heroes',
  templateUrl: './heroes.component.html',
  styleUrls: ['./heroes.component.css']
})
export class HeroesComponent implements OnInit {

  constructor() { }

  ngOnInit() {
  }

}
```

你要从Angular核心库中导入component符号，并为组件类加上 @Component装饰器

@Component是个装饰器函数，用于为该组件指定Angular所需要的元数据。

CLI自动生成了三个元数据属性：

1. Selector - 组件的选择器（CSS元素选择器）
2. templateUrl - 组件模版文件的位置
3. styleUrls - 组件私有CSS样式表文件的位置

[CSS 元素选择器](https://developer.mozilla.org/en-US/docs/Web/CSS/Type_selectors) `app-heroes` 用来在父组件的模板中匹配 HTML 元素的名称，以识别出该组件。

`ngOnInit()` 是一个[生命周期钩子](https://angular.cn/guide/lifecycle-hooks#oninit)，Angular 在创建完组件后很快就会调用 `ngOnInit()`。这里是放置初始化逻辑的好地方。

始终要 `export` 这个组件类，以便在其它地方（比如 `AppModule`）导入它。



### 添加 `hero` 属性

往 `HeroesComponent` 中添加一个 `hero` 属性，用来表示一个名叫 “Windstorm” 的英雄。

> heroes.component.ts (hero property)

```
hero = 'Windstorm';
```

### 显示英雄

打开模板文件 `heroes.component.html`。删除 Angular CLI 自动生成的默认内容，改为到 `hero` 属性的数据绑定。

> heroes.component.html

```
{{hero}}
```

## 显示 `HeroesComponent` 视图

要显示 `HeroesComponent` 你必须把它加到壳组件 `AppComponent` 的模板中。

别忘了，`app-heroes` 就是 `HeroesComponent` 的 [元素选择器](https://angular.cn/tutorial/toh-pt1#selector)。 所以，只要把 `<app-heroes>` 元素添加到 `AppComponent` 的模板文件中就可以了，就放在标题下方。

> src/app/app.component.html

```
<h1>{{title}}</h1>
<app-heroes></app-heroes>
```

如果 CLI 的 `ng serve` 命令仍在运行，浏览器就会自动刷新，并且同时显示出应用的标题和英雄的名字。



## 创建 `Hero` 类

真实的英雄当然不止一个名字。

在 `src/app` 文件夹中为 `Hero` 类创建一个文件，并添加 `id` 和 `name` 属性。

src/app/hero.ts

```
port interface Hero {
  id: number;
  name: string;
}
```

回到 `HeroesComponent` 类，并且导入这个 `Hero` 类。