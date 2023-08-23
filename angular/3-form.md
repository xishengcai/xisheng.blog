# 构建模版驱动表单

本教程将为你演示如何创建一个模板驱动表单，它的控件元素绑定到数据属性，并通过输入验证来保持数据的完整性和样式，以改善用户体验。

当在模板中进行更改时，模板驱动表单会使用[双向数据绑定](https://angular.cn/guide/architecture-components#data-binding)来更新组件中的数据模型，反之亦然。

Template-driven forms use [two-way data binding](https://angular.cn/guide/architecture-components#data-binding) to update the data model in the component as changes are made in the template and vice versa.



效果



步骤：

1. 建立基本表单
   - 定义一个范例数据模型
   - 包括必须的基础设施，比如FormModule
2. 使用ngModel 指令和双向数据绑定语法把表单控件绑定到数据属性
   - 检查ngModel如何使用CSS类报告控件状态
   - 为控件命名，以便让ngModel可以访问他们
3. 用ngModel跟踪输入的有效和控制的状态
   - 添加自定义 CSS 来根据状态提供可视化反馈。
   - 显示和隐藏验证错误信息。
4. 通过添加到模型数据来响应原生HTML按钮的单击事件
5. 使用表单的ngSubmit 输出属性来处理表单提交
   - 在表单生效之前，先禁用Submit按钮
   - 在提交完成后，把已完成的表单替换成页面上不同的内容





建立表单

1. 



