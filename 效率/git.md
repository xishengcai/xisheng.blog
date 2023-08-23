[toc]

# Git Tips

## push
```bash
git push origin refs/heads/master:refs/heads/master
```
简写
```bash
git push origin master:master
```



## Pull rebase
```bash
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

## history id

```
git log
```



## show current commit's content

```
git show
```



## commit 内容填写不规范，重写编辑

```
git commit --amend
```



## 完成撤销,同时将代码恢复到前一commit_id 对应的版本

```
git reset --hard commit_id
```



## 完成Commit命令的撤销，但是不对代码修改进行撤销 
```
git reset commit_id 
```

     

## git瘦身
```
git gc  --prune=now
```



## 完全复制其他分支

```
git reset --hard origin/${other_branch}
```



## delete remote tag

只需将"空"引用推送到远程标记名：
```bash
git push origin :tagname
```
或者，更具体地说，使用--delete选项(如果您的git版本早于1.8.0，则使用-d选项)：
```bash
git push --delete origin tagname
```
注意，Git有标记名称空间和分支名称空间，因此可以对分支和标记使用相同的名称。如果要确保不会意外地删除分支而不是标记，可以指定完全引用，它将永远不会删除分支：
```bash
git push origin :refs/tags/tagname
```



## delete local tag

```bash
git push -d tagName
```



## Pull Request For Open Source Project

You only have one commit incorrectly signed off! To fix, first ensure you have a local copy of your branch by [checking out the pull request locally via command line](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/checking-out-pull-requests-locally). Next, head to your local branch and run:

```
git commit --amend --no-edit --signoff
```

Now your commits will have your sign off. Next run

```
git push --force-with-lease origin master
```





## 删除未跟踪文件

```
git clean -fd
```





