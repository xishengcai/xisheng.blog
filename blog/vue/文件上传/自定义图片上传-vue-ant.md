# 自定义图片上传

## required：



## 在views 目录下创建 UploadFile.vue

```vue
<template>
    <div>
      <a-upload
        list-type="picture"
        v-model:file-list="fileList"
        :customRequest="upload"
      >
        <a-button>
          <upload-outlined></upload-outlined>
          upload
        </a-button>
      </a-upload>
      <br />
    </div>
 </template>
<script>
import { UploadOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';
import { defineComponent, ref } from 'vue';
import axios from 'axios';

export default defineComponent({
    name: "UploadFile",
    components: {
      UploadOutlined,
    },
    methods: {
      upload(f){
        console.log("file: ", f),
        
        axios({
            method: "post",
            url: "http://localhost:8000/api/upload",
            headers: {
                'Content-Type':'multipart/form-data',
                'uid': localStorage.getItem('uid'),
                'token':localStorage.getItem('token')
            },
            data: f,
        }).then((response)=>{
            if (response.data.code == 0){
                message.success("upload success")
            }else{
                console.log(response)
                message.error("upload failed")
            }
        })
      },


    },
    setup() {
        const fileList = ref([]);
        return {
            fileList,
        };
    }
})
 </script>


  <style scoped>
  /* tile uploaded pictures */
  .upload-list-inline :deep(.ant-upload-list-item) {
    float: left;
    width: 200px;
    margin-right: 8px;
  }
  .upload-list-inline :deep(.ant-upload-animate-enter) {
    animation-name: uploadAnimateInlineIn;
  }
  .upload-list-inline :deep(.ant-upload-animate-leave) {
    animation-name: uploadAnimateInlineOut;
  }
  </style>

  
```



## 在其他组件中引用

```vue

<template>
          <div>
                 <UploadFile></UploadFile>
          </div>

</template>

<script>
  import UploadFile from './UploadFile.vue'
</script>



```



