# xisheng.blog
## what is hugo
Hugo是一种静态网站生成器。适用于搭建个人博客、小型公司主页等网站，是一种小型的CMS系统

## install hugo
go get -v hugo

## start create you blog
hego new xisheng.blog

## new blog
hugo new post/my-first-post.md

## download them
cd themes
git clone https://github.com/vjeantet/hugo-theme-casper casper

## local debug
hugo server -t hugo-theme-techdoc --bind 0.0.0.0 --port 81 -w

## 生成public 静态文件
hugo -t hugo-theme-techdoc -d public_html

## 配置nginx代理
在 nginx 中配置public文件的位置

[hugo](https://gohugo.io/getting-started/directory-structure/)