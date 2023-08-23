```
FROM node:12.18.1-alpine

MAINTAINER EXP <caixisheng>

# 安装 nodejs 的模块：gitbook 命令行
RUN npm install gitbook-cli@2.3.2 -g

# 获取 gitbook 的官方版本并安装
# 通过 gitbook ls-remote 可以列举额 npm 上可以安装的版本号
# 但是不建议使用 3.2.3 之后的版本，官方为了收费反而阉割了不少功能
ARG GITBOOK_VERSION=3.2.3
RUN gitbook fetch $GITBOOK_VERSION


# 定义 Docker 数据卷位置 /gitbook （之后会用于映射到物理硬盘的位置）
ENV BOOKDIR /gitbook
VOLUME $BOOKDIR

# 暴露 4000 端口 （gitbook 默认的服务端口）
EXPOSE 4000

# 定义工作目录为 /gitbook
WORKDIR $BOOKDIR
COPY . .


RUN sed -i 's/\[toc\]/<!-- toc -->/g' *.md && gitbook build

# 安装完成后打印 gitbook 的帮助文档
CMD ["gitbook", "serve"]
```