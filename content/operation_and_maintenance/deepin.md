---
title: "Deepin Create Icon"
date: 2019-12-21T10:15:12+08:00
draft: false
---

### install goland
ubuntu 所有的应用是在 /usr/share/applications 里的，其中每个应用都有自己的 .desktop 文件，这就是应用程序的一些声明，我们可以书写以下的 desktop 文件来达到效果。</br>
download source code form official</br>
```
tar -zxvf xxx.tar.gz -C /usr/local
mv GoLand-2019.3 goland
```
generate icon<br>
```
[Desktop Entry]
Encoding=UTF-8
Name=goland IDE
Comment=The Smarter Way to Code
Exec=/bin/sh "/usr/local/golang/bin/goland.sh"
Icon=/usr/local/golang/bin/goland.png
Categories=Application;Development;Java;IDE
Version=2019.3
Type=Application
Terminal=0
```