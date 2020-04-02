---
title: "Git"
date: 2019-12-27T16:48:50+08:00
draft: false
---

#### 合并
```gitexclude
git add ./
git commit -m "update some"
git pull --rebase dev
    
if has conflict
    if  conflict can handle
        git add ./
        git rebase --continue
        git push origin ${your_branch}
    else
        git rebase --abort
end
```

#### show commit history id
git log

#### show current commit's content
git show

#### 多次commit后取消前面的commit
git rest --soft= ${commit_id}

#### 完成撤销,同时将代码恢复到前一commit_id 对应的版本
git reset --hard commit_id

#### 完成Commit命令的撤销，但是不对代码修改进行撤销，可以直接通过git commit 重新提交对本地代码的修改。     
git reset commit_id 
     
#### git瘦身
git gc  --prune=now

#### 完全复制其他分支
git reset --hard origin/${other_branch}