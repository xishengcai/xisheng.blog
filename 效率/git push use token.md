# GitHub使用Personal access token

报错：remote: Support for password authentication was removed on August 13, 2021. Please use a personal access token instead.
remote: Please see https://github.blog/2020-12-15-token-authentication-requirements-for-git-operations/ for more information.
fatal: unable to access 'https://github.com/sober-orange/study.git/': The requested URL returned error: 403

原因：自2021年8月13日起，github不再支持使用密码push的方式

解决方案：两种
一、 使用SSH
二、使用Personal access token

法一：使用SSH
点击此链接跳转至方法详情

法二：使用Personal access token
首先，需要获取token

点击你的GitHub头像 -> 设置 -> 开发者设置 -> Personal access tokens -> Generate new token

生成token

复制token


使用token进行push、pull、clone等操作（pull和clone等操作原理同push，只需替换push为pull或其他相应的命令即可）
使用token的方式其实原理在于将原来明文密码换为token，说白了就是token>=password，之所以我这里写了>号，是因为token的功能远大于原来的password，相比password，token具有很多其没有的用法。
我将使用token的方法进行了细分，以满足不同的使用要求。请各位根据自己的使用情况进行选择

token法一：直接push
此方法每次push都需要输一遍token，很是费劲啊



# git push https://你的token@你的仓库链接，我这里是我的仓库链接你要改成你的
git push https://你的token@github.com/sober-orange/study.git


token法二：修改remote别名
这种方式在push的时候直接指明别名就可
如果你已经设置过remote别名，使用如下命令



# 我这里的别名是origin
# git remote set-url 你的remote别名 https://你的token@你的仓库地址
git remote set-url origin https://你的token@github.com/sober-orange/study.git
# 提交代码
git push -u origin master
如果你未设置过别名，使用如下命令添加别名



# git remote add 别名 https://你的token@你的仓库地址
git remote add origin https://你的token@github.com/sober-orange/study.git
# 提交代码
git push -u origin master
token法三：使用Git Credential Manager Core (GCM Core) 记住token

git push
Username: 你的用户名
Password: 你的token
# 记住token
git config credential.helper store
toekn法四：使用Windows的凭据管理器
打开凭据管理器 -> windows凭据
找到“git:https://github.com”的条目，编辑它
用token替换你以前的密码

参考文献

https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token


https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git