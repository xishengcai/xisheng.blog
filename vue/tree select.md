

```vue
                        <a-col :span="12">
                            <a-form-item label="人才名称" name="talentID">
                                <a-select 
                                    v-model:value="contract.talentID" 
                                    show-search
                                    style="width: 100%" placeholder="请选择"
                                    :fieldNames="{ label: 'name', value: 'id' }" 
                                    :options="data.talentOption"
                                    :filter-option="false"
                                    @search="filterTalentOption"
                                    @change="changeTalentOption"
                                    >
                                </a-select>
                            </a-form-item>
                        </a-col>

<script>
// 查询人才信息
const filterTalentOption = (input) => {
    let param = {
        name: input
    }
    queryTalentList(param).then((res) => {
        if (res.data.code == 0) {
            pagination.total = res.data.data.total
            data.talentOption = res.data.data.list
            return
        }
    })
}
</script>
```





```vue
                <a-row :gutter="16">
                    <a-col :span="16">
                        <a-form-item label="业务专业" name="projectMajor">
                        <a-cascader 
                        v-model:value="talent.projectMajor" 
                        :options="projectMajor" 
                        placeholder="Please select" />
                    </a-form-item>
                    </a-col>
                </a-row>
```
