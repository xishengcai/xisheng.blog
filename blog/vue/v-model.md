# v-model

[toc]

## 原生元素

形式

```
<input v-model="searchText" />
```

编译展开

```
<input
	:value="searchText"
	@input="searchText = $event.target.value"
	/>
```



而当使用在一个组件上时，`v-model` 会被展开为如下的形式：

```
<CustomInput
	:modelValue="searchText"
	@update:modelValue="newValue" => searchText = newValue" />
```

要让这个例子实际工作起来，`<CustomInput>` 组件内部需要做两件事：

1. 将内部原生 <input> 元素的value attribute 绑定到modelValue prop
2. 当原生的input 事件触发时，触发了一个携带了新值的update: modelValue自定义事件



这里是相应的代码：

```vue
<script>
export default {
	props: ['modelValue'],
	emits: ['update:modelValue']
}
</script>
<template>
	<input
		:value="modelValue"
		@input="$emit('update:modelValue', $event.target.value)"
</template>
```



另一种在组件内实现 v-model 的方式是使用同一个可写的，同时具有getter 和 setter的computed 属性。

get方法需要返回 modelValue prop， 而set 方法需要触发相应的事件。

```vue
<script>
	props: ['modelValue'],
	emits: ['update:modelValue'],
	computed: {
		value: {
			get(){
				return this.modelValue
			},
			set(value){
				this.$emit('update:modelValue', value)
			}
		}
	}
</script>
<template>
	<input v-model="value">
</template>
```



## 参数

默认情况下， v-model 在组件上都是使用 modelValue 作为prop， 并以 update:modelValue 作为对应的事件。我们可以通过给v-model 指定一个参数来更改这些名字

```vue
<MyComponent v-model:title="bookTitle" />
```

在这个例子中，子组件应声明一个 `title` prop，并通过触发 `update:title` 事件更新父组件值：

```vue
<script>
export default {
  props: ['title'],
  emits: ['update:title']
}
</script>

<template>
	<input
 		type="text"
    :value="title"
    @input="$emit('update:title', $event.target.value)"
</template>
```





## 多个v-model 绑定

利用刚才在 [`v-model` 参数](https://cn.vuejs.org/guide/components/v-model.html#v-model-arguments)小节中学到的指定参数与事件名的技巧，我们可以在单个组件实例上创建多个 `v-model` 双向绑定。



组件上的每一个 `v-model` 都会同步不同的 prop，而无需额外的选项：

```vue
<UserName
	v-model:firstName="first"
	v-model:lastName="last"
>
```



```vue
<script>
 export default {
 	props: {
    firstName: string,
    lastName: string
  },
  emits: ['update:firstName', 'update:lastName']
 }
        
</script>
<template>
	<input
  	type="text"
    :value="firstName"
    @input="$emit('update:firstName', event.target.value)"
  />
	
	<input
   type="text"
   :value="lastName"
   @input="$emit('update:lastName', event.target.value)"
  />
</template>
```





## 处理v-model修饰符

在学习输入绑定时，我们知道了 `v-model` 有一些[内置的修饰符](https://cn.vuejs.org/guide/essentials/forms.html#modifiers)，例如 `.trim`，`.number` 和 `.lazy`。在某些场景下，你可能想要一个自定义组件的 `v-model` 支持自定义的修饰符。

我们来创建一个自定义的修饰符 `capitalize`，它会自动将 `v-model` 绑定输入的字符串值第一个字母转为大写：

```vue
<MyComponent v-model.capitalize="myText" />
```



组件的 `v-model` 上所添加的修饰符，可以通过 `modelModifiers` prop 在组件内访问到。在下面的组件中，我们声明了 `modelModifiers` 这个 prop，它的默认值是一个空对象：

```vue
<script>
export default {
  props: {
    modelValue: String,
    modelModifiers: {
      default: () => ({})
    }
  },
  emits: ['update:modelValue'],
  created() {
    console.log(this.modelModifiers) // { capitalize: true }
  }
}
</script>

<template>
  <input
    type="text"
    :value="modelValue"
    @input="$emit('update:modelValue', $event.target.value)"
  />
</template>
```

注意这里组件的 `modelModifiers` prop 包含了 `capitalize` 且其值为 `true`，因为它在模板中的 `v-model` 绑定 `v-model.capitalize="myText"` 上被使用了。

有了这个 prop，我们就可以检查 `modelModifiers` 对象的键，并编写一个处理函数来改变抛出的值。在下面的代码里，我们就是在每次 `<input />` 元素触发 `input` 事件时将值的首字母大写：

```vue
<script>
export default {
  props: {
    modelValue: String,
    modelModifiers: {
      default: () => ({})
    }
  },
  emits: ['update:modelValue'],
  methods: {
    emitValue(e) {
      let value = e.target.value
      if (this.modelModifiers.capitalize) {
        value = value.charAt(0).toUpperCase() + value.slice(1)
      }
      this.$emit('update:modelValue', value)
    }
  }
}
</script>

<template>
  <input type="text" :value="modelValue" @input="emitValue" />
</template>
```



对于又有参数又有修饰符的 `v-model` 绑定，生成的 prop 名将是 `arg + "Modifiers"`。举例来说：

```vue
<MyComponent v-model:title.capitalize="myText">
```

相应的声明应该是：

```vue
<script>
  export default {
  props: ['title', 'titleModifiers'],
  emits: ['update:title'],
  created() {
    console.log(this.titleModifiers) // { capitalize: true }
  }
}
</script>
```

