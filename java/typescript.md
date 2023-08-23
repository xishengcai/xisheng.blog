# TypeScript is what



## **一、什么是 TypeScript**

TypeScript 是近几年被火爆的应用了，这让大家产生了一个错觉：这么多的拥护者，难道TypeScript是一个新的语言？

TypeScript是微软公司开发和维护的一种面向对象的编程语言。它是JavaScript的超集，包含其所有元素。

TypeScript完全遵循OOPS的概念，在TSC（TypeScript编译器）的帮助下，我们可以将TypeScript代码（.ts文件）转换成JavaScript（.js文件）

![img](https://pic4.zhimg.com/80/v2-655a008d5c6f6983a00126cc58155927_1440w.jpg)

> TypeScript是JavaScript的超集

## **二、TypeScript 简史**

2010年，Anders Hejlsberg（TypeScript的创建者）开始在微软开发TypeScript，并于2012年向公众发布了TypeScript的第一个版本（TypeScript 0.8）。尽管TypeScript的发布受到了全世界许多人的称赞，但是由于缺少主要ide的支持，它并没有被JavaScript社区主要采用。

**TypeScript的第一个版本（TypeScript 0.8）于2012年10月发布。**

最新版本的Typescript（Typescript 3.0）于2018年7月发布，您可以在[这里](https://link.zhihu.com/?target=https%3A//www.typescriptlang.org/)下载最新版本！



## **三、为什么我们要使用TypeScript？**

- TypeScript简化了JavaScript代码，使其更易于阅读和调试。
- TypeScript是开源的。
- TypeScript为JavaScript ide和实践（如静态检查）提供了高效的开发工具。
- TypeScript使代码更易于阅读和理解。
- 使用TypeScript，我们可以大大改进普通的JavaScript。
- TypeScript为我们提供了ES6（ECMAScript 6）的所有优点，以及更高的生产率。
- TypeScript通过对代码进行类型检查，可以帮助我们避免在编写JavaScript时经常遇到的令人痛苦的错误。
- 强大的类型系统，包括泛型。
- TypeScript只不过是带有一些附加功能的JavaScript。
- TypeScript代码可以按照ES5和ES6标准编译，以支持最新的浏览器。
- 与ECMAScript对齐以实现兼容性。
- 以JavaScript开始和结束。
- 支持静态类型。
- TypeScript将节省开发人员的时间。
- TypeScript是ES3、ES5和ES6的超集。

**TypeScript的附加功能**

- 具有可选参数的函数。
- 使用REST参数的函数。
- 泛型支持。
- 模块支持。

## **四、大牛现身说法:**

- “我们喜欢TypeScript有很多方面……有了TypeScript，我们的几个团队成员说了类似的话，**我现在实际上已经理解了我们自己的大部分代码！因为他们可以轻松地遍历它并更好地理解关系。我们已经通过TypeScript的检查发现了几个漏洞。**“-Brad Green，Angular工程总监“
- Ionic的主要目标之一是**使应用程序开发尽可能快速和简单，**工具支持TypeScript为我们 提供了自动完成、类型检查和源文档*与之真正一致。”*-Tim Lancina，工具开发人员–Ionic“
- 在编写基于web或JavaScript的现代应用程序时，TypeScript是一个**明智的选择。**TypeScript经过仔细考虑的语言特性和功能，以及它不断改进的工具，带来了非常有成效的开发体验。”-Epic研究员Aaron Cornelius“
- TypeScript帮助我们**重用团队的知识**并**通过**提供与C#相同的优秀开发经验来保持相同的团队速度……比普通JavaScript有了巨大的改进。”-Valio Stoychev，PM Lead–NativeScript

## **五、你可能不知道的TypeScript顶级功能**

**1、面向对象程序设计**

TypeScript包含一组非常好的面向对象编程（OOP）特性，这些特性有助于维护健壮和干净的代码；这提高了代码质量和可维护性。这些OOP特性使TypeScript代码非常整洁和有组织性。

**例如:**

```typescript
class CustomerModel {
  customerId: number;
  companyName: string;
  contactName: string;
  country: string;
}
class CustomerOperation{
  addCustomer(customerData: CustomerModel) : number {
    // 添加用户
    let customerId = 5;// 保存后返回的ID
    return customerId;
  }
}
```



**2、接口、泛型、继承和方法访问修饰符**

TypeScript支持接口、泛型、继承和方法访问修饰符。接口是指定契约的好方法。泛型有助于提供编译时检查，继承使新对象具有现有对象的属性，访问修饰符控制类成员的可访问性。TypeScript有两个访问修饰符-public和private。默认情况下，成员是公共的，但您可以显式地向其添加公共或私有修饰符。

**（1）接口**

```typescript
interface ITax {
  taxpayerId: string;
  calculateTax(): number;
}

class IncomeTax implements ITax {
  taxpayerId: string;
  calculateTax(): number {
    return 10000;
  }
}

class ServiceTax implements ITax {
  taxpayerId: string;
  calculateTax(): number {
    return 2000;
  }
}
```



**（2）访问修饰符**

```typescript
class Customers{
  public companyname:string;
  private country:string;
}
```



**显示一个公共变量和一个私有变量**

**（3）继承**

```typescript
class Employee{
  Firstname:string;
}

class Company extends Employee {
  Department:string;
  Role:string
  private AddEmployee(){
    this.Department="myDept";
    this.Role="Manager";
    this.FirstName="Test";
  }
}
```



**（4）泛型**

```typescript
function identity<T> (arg: T): T {
  return arg; 
}
// 显示泛型实现的示例
let output = identity <string>("myString");
let outputl = identity <number> (23);
```



**（5）强/静态类型**

TypeScript不允许将值与不同的数据类型混合。如果违反了这些限制，就会抛出错误。因此，在声明变量时必须定义类型，并且除了在JavaScript中非常可能定义的类型之外，不能分配其他值。

**例如:**

```typescript
let testnumber: number = 6;
testnumber = "myNumber"; // 这将引发错误
testnumber = 5; // 这样就可以了
```



**3、编译时/静态类型检查**

如果我们不遵循任何编程语言的正确语法和语义，那么编译器就会抛出编译时错误。在删除所有语法错误或调试编译时错误之前，它们不会让程序执行一行代码。TypeScript也是如此。

**例如:**

```typescript
let isDone: boolean = false;
isDone = "345";  // 这将引发错误
isDone = true; // 这样就可以了
```

 **4、比JavaScript代码更少**

TypeScript是JavaScript的包装器，因此可以使用帮助类来减少代码。Typescript中的代码更容易理解。



**5、可读性**

接口、类等为代码提供可读性。由于代码是用类和接口编写的，因此更有意义，也更易于阅读和理解。

**举例:**

```typescript
class Greeter {
  private greeting: string;
  constructor (private message: string) {
    this.greeting = message;
  }
  greet() {
    return "Hello, " + this.greeting;
  }
}
```



**JavaScript 代码:**

```typescript
var Greeter = (function () {
  function Greeter(message) {
    this.greeting = message;
  }
  Greeter.prototype.greet = function () {
    return "Hello, " + this.greeting;
  };
  return Greeter;
})();
```



**6、兼容性**

Typescript与JavaScript库兼容，比如 `underscore.js`，`Lodash`等。它们有许多内置且易于使用的功能，使开发更快。



**7、提供可以将代码转换为JavaScript等效代码的“编译器”**

TypeScript代码由纯JavaScript代码以及特定于TypeScript的某些关键字和构造组成。但是，编译TypeScript代码时，它会转换为普通的JavaScript。这意味着生成的JavaScript可以与任何支持JavaScript的浏览器一起使用。



**8、支持模块**

随着TypeScript代码基的增长，组织类和接口以获得更好的可维护性变得非常重要。TypeScript模块允许您这样做。模块是代码的容器，可以帮助您以整洁的方式组织代码。从概念上讲，您可能会发现它们类似于.NET命名空间。

**例如:**

```typescript
module Company {
  class Employee {
  }
  
  class EmployeeHelper {
    targetEmployee: Employee;
  }
  
  export class Customer {
  }
}
var obj = new Company.Customer();
```

**9、ES6 功能支持**

Typescript是ES6的一个超集，所以ES6的所有特性它都有。另外还有一些特性，比如它支持通常称为lambda函数的箭头函数。ES6引入了一种稍微不同的语法来定义匿名函数，称为胖箭头(fat arrow)语法。

**举例:**

```
setTimeout(() => {
   console.log("setTimeout called!")
}, 1000);
```

**10、在流行的框架中使用**

TypeScript在过去几年里越来越流行。也许TypeScript流行的决定性时刻是Angular2正式转换到TS的时候，这是一个双赢的局面。

**11、减少错误**

它减少了诸如空处理、未定义等错误。强类型特性，通过适当的类型检查限制开发人员，来编写特定类型的代码。

**12、函数重载**

TypeScript允许您定义重载函数。这样，您可以根据参数调用函数的不同实现。但是，请记住，TypeScript函数重载有点奇怪，需要在实现期间进行类型检查。这种限制是由于TypeScript代码最终被编译成纯JavaScript，而JavaScript不支持真正意义上的函数重载概念。

**例如:**

```
class functionOverloading{
  addCustomer(custId: number);
  addCustomer(company: string);
  addCustomer(value: any) {
    if (value && typeof value == "number") {
      alert("First overload - " + value);
    }
    if (value && typeof value == "string") {
      alert("Second overload - " + value);
    }
  }
}
```



**13、构造器**

在TypeScript中定义的类可以有构造函数。构造函数通常通过将默认值设置为其属性来完成初始化对象的工作。构造函数也可以像函数一样重载。

**例如:**

```
export class SampleClass{
  private title: string; 
  constructor(public constructorexample: string){
    this.title = constructorexample; 
  }
}
```



**14、调试**

用TypeScript编写的代码很容易调试。

**15、TypeScript只是JavaScript**

TypeScript始于JavaScript，止于JavaScript。Typescript采用JavaScript中程序的基本构建块。为了执行的目的，所有类型脚本代码都转换为其JavaScript等效代码。

**例如:**

```
class Greeter {
  greeting: string;
  constructor (message: string) {
    this.greeting = message;
  }
  greet() {
    return "Hello, " + this.greeting;
  }
}
```

**JavaScript 代码:**

```
var Greeter = (function () {
  function Greeter(message) {
    this.greeting = message;
  }
  Greeter.prototype.greet = function () {
    return "Hello, " + this.greeting;
  };
  return Greeter;
})();
```



**16、可移植性**

TypeScript可以跨浏览器、设备和操作系统移植。它可以在JavaScript运行的任何环境中运行。与对应的脚本不同，TypeScript不需要专用的VM或特定的运行时环境来执行。

