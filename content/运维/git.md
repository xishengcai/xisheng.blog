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

#### git瘦身
git gc  --prune=now

#### 完全复制其他分支
git reset --hard origin/${other_branch}