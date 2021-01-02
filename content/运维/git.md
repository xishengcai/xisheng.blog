---
title: "Git"
date: 2019-12-27T16:48:50+08:00
draft: false
---

### 将分支、标记或其他引用推送到远程存储库需要指定"哪个repo、哪个源、哪个目标？"
```shell script
git push remote-repo source-ref:destination-ref
```

### 推送分支和标签
#### 将主分支推到源站主分支的真实示例是：
```shell script
git push origin refs/heads/master:refs/heads/master
```
简写
```shell script
git push origin master:master
```

#### 标签的工作方式相同：
```shell script
git push origin refs/tags/release-1.0:refs/tags/release-1.0
```
简写
```shell script
git push origin release-1.0:release-1.0
```

#### origin/dev merge to local then push
```gitexclude
git add ./
git commit -m "update some"
git pull --rebase origin/dev
    
if has conflict
    if  conflict can handle
        git add ./
        git rebase --continue
    else
        git rebase --abort
else
    git push origin ${your_branch}
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

### delete remote tag
只需将"空"引用推送到远程标记名：
```shell script
git push origin :tagname
```
或者，更具体地说，使用--delete选项(如果您的git版本早于1.8.0，则使用-d选项)：
```shell script
git push --delete origin tagname
```
注意，Git有标记名称空间和分支名称空间，因此可以对分支和标记使用相同的名称。如果要确保不会意外地删除分支而不是标记，可以指定完全引用，它将永远不会删除分支：
```shell script
git push origin :refs/tags/tagname
```

### delete local tag
```shell script
git push -d tagName
```
