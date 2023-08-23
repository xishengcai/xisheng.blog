### 组件设计

组件支持的`API`如下(参考`element ui`):

- `name` : 文件上传时前端需要和服务端约定的`key`
- `limit`: 文件上传数量
- `fileList`: 已经上传的文件列表
- `action`: 文件上传地址
- `beforeUpload`: 上传之前的钩子函数
- `onChange`: 上传过程中文件信息发生更改触发的回调
- `onSuccess/onError/onProgress`: 上传成功/错误/进度回调函数
- `onExceed`: 超出最大上传数量时触发的回调
- `data`: 额外参数组成的对象，最终会遍历以`key/value`键值对的形式`append`到`formData`中
- `multiple`: 是否支持多个文件上传
- `accept`: 上传接收的文件类型
- `customHttpRequest`: 支持自定义请求函数
- `drag`: 是否启用拖拽上传





```vue
<template>
  <go-upload name="file" :limit="3" multiple on-exceed="onExceed" :action="action">
    <go-button color="primary">click to upload</go-button>
  </go-upload>
</template>

<script>
export default {
  data () {
    return {
      action: 'https://afternoon-dawn-09444.herokuapp.com/upload'
    };
  },
  methods: {
    onExceed() {

    }
  }
};
</script>
```





```vue

```

