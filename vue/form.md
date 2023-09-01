# ant form



## 格式

```vue
<a-form
	ref="formRef"
	name=""
	:model="dynamicValidateForm"
	v-bind="formItemLayoutWithOutLabel">
  
  <a-form-item
  	v-for="(domain, index) in dynamicValidateForm.domains"
    :key="domain.key"
    v-bind="index === 0 ? formItemLayout : {}"
    :label="index === 0 ? 'Domains' : ''"
    :name=['domains', index, 'value']
    :rules="{
    	required: true,
      message: 'domain can not be null'
      trigger: 'change'
   }">
  
    <a-input
     v-model:value="domain.value"
     placeholder="please input domain"
     style="width:60%;margin-right: 8px"       
     ></a-input>
    
    <MinusCircleOutlined
      v-if="dynamicValidateForm.domains.length > 1"                  
      class="dynamic-delete-button"
      :disable="dynamicValidateForm.domains.length === 1" 
      @click="remove(domain)"  />                
  </a-form-item>
  
  <a-form-item v-bind="formItemLayoutWithOutLabel">
  	<a-button type="dashed" style="width: 60%"  @click="addDomain">
    	<PlusOutlined />
        Add field
    </a-button>
  </a-form-item>
  
  <a-form-item v-bind="formItemLayoutWithOutLabel">
  	<a-button type="primary" html-type="submit" @click="submitForm">Submit</a-button>
    <a-button style="margin-left: 10px" @click="resetForm">Reset</a-button>
  </a-form-item>
  </a-form>
  
<script>
import {MinusCricleOutline, PlusOutlined } from '@ant-design/icons-vue'
import {defineComponent, reactive, ref} from 'vue'

export default defineComponent {
  components: {
    MinusCircleOutlined,
    PlusOutlined,
  },
  setup(){
    const formRef = ref();
    const formItemLayout = {
      
    }
   
  }
}
</script>
      
```





## add item





## remove item











