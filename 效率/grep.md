# grep Tips



`grep`是Linux中用于文本处理的最有用和功能最强大的命令之一。`grep`在一个或多个输入文件中搜索与正则表达式匹配的行，并将每条匹配的行写入到标准输出。

正则表达式是与一组字符串匹配的模式。模式由运算符，文字字符和元字符组成，它们具有特殊的含义。GNU `grep`支持三种正则表达式语法Basic，Extended和Perl-compatible。

当没有给出正则表达式类型时，`grep`以Basic的形式调用，`grep`将搜索模式解释为基本Basic正则表达式。要将模式解释为扩展Extended的正则表达式，请使用`-E`/`--extended-regexp`选项。

在GNU `grep`的实现中，基本正则表达式和扩展正则表达式语法之间在功能上没有区别，且两者一样。

唯一的区别是，在基本正则表达式中的元字符`?`，`+`，`{`，`|`，`(`和`)`被解释为文字字符，即不将这些字符作为正则解释。

为了在使用基本正则表达式时保持元字符的特殊含义，必须使用反斜杠`\`对字符进行转义。稍后我们将解释这些和其他元字符的含义。

通常，您应始终将正则表达式括在单引号中，以避免shell解释和执行元字符在shell在意义。

## 字符匹配

`grep`命令的最基本用法是在文件中搜索字符或字符串。除了在可以搜索文件的内容之外，grep还可以搜索标准输入的内容。

例如要搜索使用`bash`作为默认的登录shell用户，则可以在`/etc/passwd`文件中搜索包含`bash`字符串的所有行。

以下`grep`命令将搜索文件的内容，然后打印包含使用bash作为登录shell的用户：

```bash
grep bash /etc/passwd
```

输出应如下所示：

```
root:x:0:0:root:/root:/bin/bash
myfreax:x:1000:1000:myfreax:/home/myfreax:/bin/bash
```

在此示例中，字符串`bash`是一个基本的正则表达式，由四个字符组成。这告诉`grep`搜索紧随其后的`b`，`a`，`s`，`h`字符串。

默认情况下，`grep`命令区分大小写。这意味着将大写和小写字符视为不同的字符。要在搜索时忽略大小写，请使用`-i`/`--ignore-case`选项。

值得一提的是`grep`将搜索模式作为字符串而不是单词进行搜索/查找。因此，如果您要搜索`gnu`，`grep`还将打印在较大的单词中嵌入gnu的行。例如`cygnus`或`magnum`。

如果搜索一个完全限定的字符串或者包含空格的字符串，则需要将其用单引号或双引号引起来，这：

```bash
grep "Gnome Display Manager" /etc/passwd
```

## 行头与行尾

`^`脱字符号表示与行的开头的字符串匹配。如果正则表达式以`^`开头，`grep`将在每行的开头开始匹配`^`之后的字符串。

以下`grep`命令将从文件`file.txt`中搜索以字符串`linux`开头的行：

```bash
grep '^linux' file.txt
```

`$`美元符号与行的结尾字符串匹配。`$`之后表示你需要搜索的内容。`grep`将在每行的行尾匹配`$`之后的字符串。

以下`grep`命令将从文件`file.txt`中搜索以字符串linux结尾的行：

```bash
grep 'linux$' file.txt
```

除了搜索行的开头和结尾，您还可以组合使用由`^关键词$`构造的正则表达式。将允许搜索指定的内容，不是嵌入大字符串匹配的行。

另一个有用的例子是组合使用`^$`模式匹配所有空行，即开头与结束都没有内容。这在查找空行时特别有用。

以下`grep`命令将从文件`file.txt`中搜索仅包含`linux`的行：

```bash
grep '^linux$' file.txt
```

## 匹配单个字符

`.`符号是与任何单个字符匹配的元字符。

例如，要包括kan，然后有两个字符并以字符串roo”结尾的任何内容，则可以使用以下模式：

```bash
grep 'kan..roo' file.txt
```

## 中括号表达式

`[]`中括号表达式允许将字符括在中括号`[]`来匹配一组字符。即从中括号`[]`内的字符串任意使用一个字符来匹配行。

例如，以下`grep`命令将从文件`file.txt`中搜索包含`accept`或`accent`的行：

```bash
grep 'acce[np]t' file.txt
```

如果方括号内的第一个字符是符号`^`，则它将匹配方括号中未括起来的任意字符。

以下模式将匹配包含除`l`之外的`co.a`字符串，`.`表示任意字符。例如`coca`，`cobalt`的任意字符串组合，但不匹配包含`cola`的行 。

例如，以下`grep`命令将从文件`file.txt`中搜索不`cola`的行：

```bash
grep 'co[^l]a' file.txt
```

您可以通过指定以连字符分隔的范围的第一个和最后一个字符来构造范围表达式，在中括号表达式内指定一系列字符，而不是一个一个地写完所有字符。

例如，`[a-e]`等同于`[abcde]`，`[1-3]`等同于`[123]`。以下表达式匹配以大写字母开头的每一行：

```bash
grep '^[A-Z]' file.txt
```

`grep`还支持中括号包含的预定义字符类别。`[:alnum:]`表示匹配单个数字与字母字符，与`[0-9A-Za-z]`一样。`[:alpha:]`表示匹配单个字母字符，与`[A-Za-z]`一样。

`[:blank:]`表示匹配单个空格和制表符。`[:digit:]`表示匹配单个数字`0 1 2 3 4 5 6 7 8 9`。

<iframe id="aswift_2" name="aswift_2" sandbox="allow-forms allow-popups allow-popups-to-escape-sandbox allow-same-origin allow-scripts allow-top-navigation-by-user-activation" width="736" height="280" frameborder="0" marginwidth="0" marginheight="0" vspace="0" hspace="0" allowtransparency="true" scrolling="no" src="https://googleads.g.doubleclick.net/pagead/ads?client=ca-pub-9716082213503633&amp;output=html&amp;h=280&amp;adk=2106567869&amp;adf=520100227&amp;pi=t.aa~a.1818994006~i.47~rp.4&amp;w=736&amp;fwrn=4&amp;fwrnh=100&amp;lmt=1689906138&amp;num_ads=1&amp;rafmt=1&amp;armr=3&amp;sem=mc&amp;pwprc=6096613189&amp;ad_type=text_image&amp;format=736x280&amp;url=https%3A%2F%2Fwww.myfreax.com%2Fregular-expressions-in-grep%2F&amp;fwr=0&amp;pra=3&amp;rh=184&amp;rw=736&amp;rpe=1&amp;resp_fmts=3&amp;wgl=1&amp;fa=27&amp;adsid=ChAI8LbjpQYQvNybtPj6jeBAEjkAx3rfGGQG38EkQX918BqYyxKqVXieY8kRUZN3ad2Agb_EJ5umWG200WIaJtqNH_lV7gilJj_AORg&amp;uach=WyJtYWNPUyIsIjEwLjE1LjciLCJ4ODYiLCIiLCIxMTQuMC41NzM1LjE5OCIsW10sMCxudWxsLCI2NCIsW1siTm90LkEvQnJhbmQiLCI4LjAuMC4wIl0sWyJDaHJvbWl1bSIsIjExNC4wLjU3MzUuMTk4Il0sWyJHb29nbGUgQ2hyb21lIiwiMTE0LjAuNTczNS4xOTgiXV0sMF0.&amp;dt=1689906138243&amp;bpp=6&amp;bdt=1287&amp;idt=-M&amp;shv=r20230719&amp;mjsv=m202307170101&amp;ptt=9&amp;saldr=aa&amp;abxe=1&amp;cookie=ID%3D267680f0e0e703e2-22aab73669e200ef%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_Ma4CoNJpCtn2ymrq0x8wL57mStY_A&amp;gpic=UID%3D00000cd9d7acaa9c%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_MYX4faEHMsnXIVhi546KrE2x4sbQA&amp;prev_fmts=0x0&amp;nras=2&amp;correlator=5263724623299&amp;frm=20&amp;pv=1&amp;ga_vid=190543355.1689822496&amp;ga_sid=1689906137&amp;ga_hid=2053081995&amp;ga_fc=1&amp;u_tz=480&amp;u_his=3&amp;u_h=1050&amp;u_w=1680&amp;u_ah=985&amp;u_aw=1680&amp;u_cd=30&amp;u_sd=2&amp;dmc=8&amp;adx=320&amp;ady=4676&amp;biw=1680&amp;bih=809&amp;scr_x=0&amp;scr_y=3907&amp;eid=44759927%2C44759837%2C44759876%2C31076089%2C31076159%2C42531706%2C44788441&amp;oid=2&amp;pvsid=2801476532134879&amp;tmod=247382133&amp;uas=0&amp;nvt=3&amp;ref=https%3A%2F%2Fwww.google.com%2F&amp;fc=1408&amp;brdim=0%2C23%2C0%2C23%2C1680%2C23%2C1680%2C977%2C1680%2C809&amp;vis=1&amp;rsz=%7C%7Cs%7C&amp;abl=NS&amp;fu=128&amp;bc=31&amp;jar=2023-07-21-01&amp;ifi=3&amp;uci=a!3&amp;fsb=1&amp;xpc=GMq45wiO59&amp;p=https%3A//www.myfreax.com&amp;dtd=25" data-google-container-id="a!3" data-google-query-id="COiu0vjenoADFQLjvAodfLsKIw" data-load-complete="true" style="border: 0px; box-sizing: border-box; --tw-border-spacing-x:  0; --tw-border-spacing-y:  0; --tw-translate-x:  0; --tw-translate-y:  0; --tw-rotate:  0; --tw-skew-x:  0; --tw-skew-y:  0; --tw-scale-x:  1; --tw-scale-y:  1; --tw-pan-x:  ; --tw-pan-y:  ; --tw-pinch-zoom:  ; --tw-scroll-snap-strictness:  proximity; --tw-ordinal:  ; --tw-slashed-zero:  ; --tw-numeric-figure:  ; --tw-numeric-spacing:  ; --tw-numeric-fraction:  ; --tw-ring-inset:  ; --tw-ring-offset-width:  0px; --tw-ring-offset-color:  #fff; --tw-ring-color:  rgba(59,130,246,0.5); --tw-ring-offset-shadow:  0 0 #0000; --tw-ring-shadow:  0 0 #0000; --tw-shadow:  0 0 #0000; --tw-shadow-colored:  0 0 #0000; --tw-blur:  ; --tw-brightness:  ; --tw-contrast:  ; --tw-grayscale:  ; --tw-hue-rotate:  ; --tw-invert:  ; --tw-saturate:  ; --tw-sepia:  ; --tw-drop-shadow:  ; --tw-backdrop-blur:  ; --tw-backdrop-brightness:  ; --tw-backdrop-contrast:  ; --tw-backdrop-grayscale:  ; --tw-backdrop-hue-rotate:  ; --tw-backdrop-invert:  ; --tw-backdrop-opacity:  ; --tw-backdrop-saturate:  ; --tw-backdrop-sepia:  ; display: block; vertical-align: middle; left: 0px; top: 0px; width: 736px; height: 280px;"></iframe>

[:lower:]表示匹配单个小写字母字符，与`[a-z]`一样。[:upper:]表示匹配单个大写字母，与`[A-Z]`一样。

## 量词

量词可让您指定匹配项必须出现的次数，即匹配关键词可以被多次匹配。以下是一些GNU `grep`支持的量词。

`*`表示匹配零次或者多次。`?`表示将前一项匹配零或一次，`+`表示匹配前一项一次或多次。{n}匹配前一项`n`次，`n`是数字。

<iframe id="aswift_3" name="aswift_3" sandbox="allow-forms allow-popups allow-popups-to-escape-sandbox allow-same-origin allow-scripts allow-top-navigation-by-user-activation" width="736" height="0" frameborder="0" marginwidth="0" marginheight="0" vspace="0" hspace="0" allowtransparency="true" scrolling="no" src="https://googleads.g.doubleclick.net/pagead/ads?client=ca-pub-9716082213503633&amp;output=html&amp;h=280&amp;adk=2106567869&amp;adf=1910640800&amp;pi=t.aa~a.1818994006~i.51~rp.4&amp;w=736&amp;fwrn=4&amp;fwrnh=100&amp;lmt=1689906138&amp;num_ads=1&amp;rafmt=1&amp;armr=3&amp;sem=mc&amp;pwprc=6096613189&amp;ad_type=text_image&amp;format=736x280&amp;url=https%3A%2F%2Fwww.myfreax.com%2Fregular-expressions-in-grep%2F&amp;fwr=0&amp;pra=3&amp;rh=184&amp;rw=736&amp;rpe=1&amp;resp_fmts=3&amp;wgl=1&amp;fa=27&amp;adsid=ChAI8LbjpQYQvNybtPj6jeBAEjkAx3rfGGQG38EkQX918BqYyxKqVXieY8kRUZN3ad2Agb_EJ5umWG200WIaJtqNH_lV7gilJj_AORg&amp;uach=WyJtYWNPUyIsIjEwLjE1LjciLCJ4ODYiLCIiLCIxMTQuMC41NzM1LjE5OCIsW10sMCxudWxsLCI2NCIsW1siTm90LkEvQnJhbmQiLCI4LjAuMC4wIl0sWyJDaHJvbWl1bSIsIjExNC4wLjU3MzUuMTk4Il0sWyJHb29nbGUgQ2hyb21lIiwiMTE0LjAuNTczNS4xOTgiXV0sMF0.&amp;dt=1689906138243&amp;bpp=7&amp;bdt=1287&amp;idt=-M&amp;shv=r20230719&amp;mjsv=m202307170101&amp;ptt=9&amp;saldr=aa&amp;abxe=1&amp;cookie=ID%3D267680f0e0e703e2-22aab73669e200ef%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_Ma4CoNJpCtn2ymrq0x8wL57mStY_A&amp;gpic=UID%3D00000cd9d7acaa9c%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_MYX4faEHMsnXIVhi546KrE2x4sbQA&amp;prev_fmts=0x0%2C736x280&amp;nras=3&amp;correlator=5263724623299&amp;frm=20&amp;pv=1&amp;ga_vid=190543355.1689822496&amp;ga_sid=1689906137&amp;ga_hid=2053081995&amp;ga_fc=1&amp;u_tz=480&amp;u_his=3&amp;u_h=1050&amp;u_w=1680&amp;u_ah=985&amp;u_aw=1680&amp;u_cd=30&amp;u_sd=2&amp;dmc=8&amp;adx=320&amp;ady=5278&amp;biw=1680&amp;bih=809&amp;scr_x=0&amp;scr_y=3907&amp;eid=44759927%2C44759837%2C44759876%2C31076089%2C31076159%2C42531706%2C44788441&amp;oid=2&amp;pvsid=2801476532134879&amp;tmod=247382133&amp;uas=0&amp;nvt=3&amp;ref=https%3A%2F%2Fwww.google.com%2F&amp;fc=1408&amp;brdim=0%2C23%2C0%2C23%2C1680%2C23%2C1680%2C977%2C1680%2C809&amp;vis=1&amp;rsz=%7C%7Cs%7C&amp;abl=NS&amp;fu=128&amp;bc=31&amp;jar=2023-07-21-01&amp;ifi=4&amp;uci=a!4&amp;btvi=1&amp;fsb=1&amp;xpc=HNk1K686Gm&amp;p=https%3A//www.myfreax.com&amp;dtd=31" data-google-container-id="a!4" data-google-query-id="COW80vjenoADFUZFwgUdRI0I9A" data-load-complete="true" style="border: 0px; box-sizing: border-box; --tw-border-spacing-x:  0; --tw-border-spacing-y:  0; --tw-translate-x:  0; --tw-translate-y:  0; --tw-rotate:  0; --tw-skew-x:  0; --tw-skew-y:  0; --tw-scale-x:  1; --tw-scale-y:  1; --tw-pan-x:  ; --tw-pan-y:  ; --tw-pinch-zoom:  ; --tw-scroll-snap-strictness:  proximity; --tw-ordinal:  ; --tw-slashed-zero:  ; --tw-numeric-figure:  ; --tw-numeric-spacing:  ; --tw-numeric-fraction:  ; --tw-ring-inset:  ; --tw-ring-offset-width:  0px; --tw-ring-offset-color:  #fff; --tw-ring-color:  rgba(59,130,246,0.5); --tw-ring-offset-shadow:  0 0 #0000; --tw-ring-shadow:  0 0 #0000; --tw-shadow:  0 0 #0000; --tw-shadow-colored:  0 0 #0000; --tw-blur:  ; --tw-brightness:  ; --tw-contrast:  ; --tw-grayscale:  ; --tw-hue-rotate:  ; --tw-invert:  ; --tw-saturate:  ; --tw-sepia:  ; --tw-drop-shadow:  ; --tw-backdrop-blur:  ; --tw-backdrop-brightness:  ; --tw-backdrop-contrast:  ; --tw-backdrop-grayscale:  ; --tw-backdrop-hue-rotate:  ; --tw-backdrop-invert:  ; --tw-backdrop-opacity:  ; --tw-backdrop-saturate:  ; --tw-backdrop-sepia:  ; display: block; vertical-align: middle; left: 0px; top: 0px; width: 736px; height: 0px;"></iframe>

`{n,}`至少匹配n次。 `{,m}`最多匹配前一项m次。 {n,m}匹配前一项必须出现次数是从n-m次，如果是{2,4}，即2至4次。

<iframe id="aswift_4" name="aswift_4" sandbox="allow-forms allow-popups allow-popups-to-escape-sandbox allow-same-origin allow-scripts allow-top-navigation-by-user-activation" width="736" height="0" frameborder="0" marginwidth="0" marginheight="0" vspace="0" hspace="0" allowtransparency="true" scrolling="no" src="https://googleads.g.doubleclick.net/pagead/ads?client=ca-pub-9716082213503633&amp;output=html&amp;h=280&amp;adk=2106567869&amp;adf=1334744306&amp;pi=t.aa~a.1818994006~i.52~rp.4&amp;w=736&amp;fwrn=4&amp;fwrnh=100&amp;lmt=1689906138&amp;num_ads=1&amp;rafmt=1&amp;armr=3&amp;sem=mc&amp;pwprc=6096613189&amp;ad_type=text_image&amp;format=736x280&amp;url=https%3A%2F%2Fwww.myfreax.com%2Fregular-expressions-in-grep%2F&amp;fwr=0&amp;pra=3&amp;rh=184&amp;rw=736&amp;rpe=1&amp;resp_fmts=3&amp;wgl=1&amp;fa=27&amp;adsid=ChAI8LbjpQYQvNybtPj6jeBAEjkAx3rfGGQG38EkQX918BqYyxKqVXieY8kRUZN3ad2Agb_EJ5umWG200WIaJtqNH_lV7gilJj_AORg&amp;uach=WyJtYWNPUyIsIjEwLjE1LjciLCJ4ODYiLCIiLCIxMTQuMC41NzM1LjE5OCIsW10sMCxudWxsLCI2NCIsW1siTm90LkEvQnJhbmQiLCI4LjAuMC4wIl0sWyJDaHJvbWl1bSIsIjExNC4wLjU3MzUuMTk4Il0sWyJHb29nbGUgQ2hyb21lIiwiMTE0LjAuNTczNS4xOTgiXV0sMF0.&amp;dt=1689906138243&amp;bpp=6&amp;bdt=1287&amp;idt=-M&amp;shv=r20230719&amp;mjsv=m202307170101&amp;ptt=9&amp;saldr=aa&amp;abxe=1&amp;cookie=ID%3D267680f0e0e703e2-22aab73669e200ef%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_Ma4CoNJpCtn2ymrq0x8wL57mStY_A&amp;gpic=UID%3D00000cd9d7acaa9c%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_MYX4faEHMsnXIVhi546KrE2x4sbQA&amp;prev_fmts=0x0%2C736x280%2C736x280&amp;nras=4&amp;correlator=5263724623299&amp;frm=20&amp;pv=1&amp;ga_vid=190543355.1689822496&amp;ga_sid=1689906137&amp;ga_hid=2053081995&amp;ga_fc=1&amp;u_tz=480&amp;u_his=3&amp;u_h=1050&amp;u_w=1680&amp;u_ah=985&amp;u_aw=1680&amp;u_cd=30&amp;u_sd=2&amp;dmc=8&amp;adx=320&amp;ady=5665&amp;biw=1680&amp;bih=809&amp;scr_x=0&amp;scr_y=3907&amp;eid=44759927%2C44759837%2C44759876%2C31076089%2C31076159%2C42531706%2C44788441&amp;oid=2&amp;pvsid=2801476532134879&amp;tmod=247382133&amp;uas=0&amp;nvt=3&amp;ref=https%3A%2F%2Fwww.google.com%2F&amp;fc=1408&amp;brdim=0%2C23%2C0%2C23%2C1680%2C23%2C1680%2C977%2C1680%2C809&amp;vis=1&amp;rsz=%7C%7Cs%7C&amp;abl=NS&amp;fu=128&amp;bc=31&amp;jar=2023-07-21-01&amp;ifi=5&amp;uci=a!5&amp;btvi=2&amp;fsb=1&amp;xpc=26A1HqQf9a&amp;p=https%3A//www.myfreax.com&amp;dtd=35" data-google-container-id="a!5" data-google-query-id="CL3w0vjenoADFfpAwgUd-xMJFQ" data-load-complete="true" style="border: 0px; box-sizing: border-box; --tw-border-spacing-x:  0; --tw-border-spacing-y:  0; --tw-translate-x:  0; --tw-translate-y:  0; --tw-rotate:  0; --tw-skew-x:  0; --tw-skew-y:  0; --tw-scale-x:  1; --tw-scale-y:  1; --tw-pan-x:  ; --tw-pan-y:  ; --tw-pinch-zoom:  ; --tw-scroll-snap-strictness:  proximity; --tw-ordinal:  ; --tw-slashed-zero:  ; --tw-numeric-figure:  ; --tw-numeric-spacing:  ; --tw-numeric-fraction:  ; --tw-ring-inset:  ; --tw-ring-offset-width:  0px; --tw-ring-offset-color:  #fff; --tw-ring-color:  rgba(59,130,246,0.5); --tw-ring-offset-shadow:  0 0 #0000; --tw-ring-shadow:  0 0 #0000; --tw-shadow:  0 0 #0000; --tw-shadow-colored:  0 0 #0000; --tw-blur:  ; --tw-brightness:  ; --tw-contrast:  ; --tw-grayscale:  ; --tw-hue-rotate:  ; --tw-invert:  ; --tw-saturate:  ; --tw-sepia:  ; --tw-drop-shadow:  ; --tw-backdrop-blur:  ; --tw-backdrop-brightness:  ; --tw-backdrop-contrast:  ; --tw-backdrop-grayscale:  ; --tw-backdrop-hue-rotate:  ; --tw-backdrop-invert:  ; --tw-backdrop-opacity:  ; --tw-backdrop-saturate:  ; --tw-backdrop-sepia:  ; display: block; vertical-align: middle; left: 0px; top: 0px; width: 736px; height: 0px;"></iframe>

现在我们已经了解正则表达式的量词，接下来我们将使用量词作为示例。在grep使用量词进行搜索，以及如何避免shell解释特殊字符`*`，`?`等。

`*`字符与前面的字符匹配零次或多次。以下`grep`命令示例将匹配`sright`，`right` ，`ssright`等。

<iframe id="aswift_5" name="aswift_5" sandbox="allow-forms allow-popups allow-popups-to-escape-sandbox allow-same-origin allow-scripts allow-top-navigation-by-user-activation" width="736" height="0" frameborder="0" marginwidth="0" marginheight="0" vspace="0" hspace="0" allowtransparency="true" scrolling="no" src="https://googleads.g.doubleclick.net/pagead/ads?client=ca-pub-9716082213503633&amp;output=html&amp;h=280&amp;adk=2106567869&amp;adf=4192125805&amp;pi=t.aa~a.1818994006~i.54~rp.4&amp;w=736&amp;fwrn=4&amp;fwrnh=100&amp;lmt=1689906138&amp;num_ads=1&amp;rafmt=1&amp;armr=3&amp;sem=mc&amp;pwprc=6096613189&amp;ad_type=text_image&amp;format=736x280&amp;url=https%3A%2F%2Fwww.myfreax.com%2Fregular-expressions-in-grep%2F&amp;fwr=0&amp;pra=3&amp;rh=184&amp;rw=736&amp;rpe=1&amp;resp_fmts=3&amp;wgl=1&amp;fa=27&amp;adsid=ChAI8LbjpQYQvNybtPj6jeBAEjkAx3rfGGQG38EkQX918BqYyxKqVXieY8kRUZN3ad2Agb_EJ5umWG200WIaJtqNH_lV7gilJj_AORg&amp;uach=WyJtYWNPUyIsIjEwLjE1LjciLCJ4ODYiLCIiLCIxMTQuMC41NzM1LjE5OCIsW10sMCxudWxsLCI2NCIsW1siTm90LkEvQnJhbmQiLCI4LjAuMC4wIl0sWyJDaHJvbWl1bSIsIjExNC4wLjU3MzUuMTk4Il0sWyJHb29nbGUgQ2hyb21lIiwiMTE0LjAuNTczNS4xOTgiXV0sMF0.&amp;dt=1689906138243&amp;bpp=8&amp;bdt=1287&amp;idt=8&amp;shv=r20230719&amp;mjsv=m202307170101&amp;ptt=9&amp;saldr=aa&amp;abxe=1&amp;cookie=ID%3D267680f0e0e703e2-22aab73669e200ef%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_Ma4CoNJpCtn2ymrq0x8wL57mStY_A&amp;gpic=UID%3D00000cd9d7acaa9c%3AT%3D1689822496%3ART%3D1689906137%3AS%3DALNI_MYX4faEHMsnXIVhi546KrE2x4sbQA&amp;prev_fmts=0x0%2C736x280%2C736x280%2C736x280&amp;nras=5&amp;correlator=5263724623299&amp;frm=20&amp;pv=1&amp;ga_vid=190543355.1689822496&amp;ga_sid=1689906137&amp;ga_hid=2053081995&amp;ga_fc=1&amp;u_tz=480&amp;u_his=3&amp;u_h=1050&amp;u_w=1680&amp;u_ah=985&amp;u_aw=1680&amp;u_cd=30&amp;u_sd=2&amp;dmc=8&amp;adx=320&amp;ady=6134&amp;biw=1680&amp;bih=809&amp;scr_x=0&amp;scr_y=3907&amp;eid=44759927%2C44759837%2C44759876%2C31076089%2C31076159%2C42531706%2C44788441&amp;oid=2&amp;pvsid=2801476532134879&amp;tmod=247382133&amp;uas=0&amp;nvt=3&amp;ref=https%3A%2F%2Fwww.google.com%2F&amp;fc=1408&amp;brdim=0%2C23%2C0%2C23%2C1680%2C23%2C1680%2C977%2C1680%2C809&amp;vis=1&amp;rsz=%7C%7Cs%7C&amp;abl=NS&amp;fu=128&amp;bc=31&amp;jar=2023-07-21-01&amp;ifi=6&amp;uci=a!6&amp;btvi=3&amp;fsb=1&amp;xpc=ywNy7UHmoM&amp;p=https%3A//www.myfreax.com&amp;dtd=40" data-google-container-id="a!6" data-google-query-id="CPKz1PjenoADFYMuvAod1MIFxA" data-load-complete="true" style="border: 0px; box-sizing: border-box; --tw-border-spacing-x:  0; --tw-border-spacing-y:  0; --tw-translate-x:  0; --tw-translate-y:  0; --tw-rotate:  0; --tw-skew-x:  0; --tw-skew-y:  0; --tw-scale-x:  1; --tw-scale-y:  1; --tw-pan-x:  ; --tw-pan-y:  ; --tw-pinch-zoom:  ; --tw-scroll-snap-strictness:  proximity; --tw-ordinal:  ; --tw-slashed-zero:  ; --tw-numeric-figure:  ; --tw-numeric-spacing:  ; --tw-numeric-fraction:  ; --tw-ring-inset:  ; --tw-ring-offset-width:  0px; --tw-ring-offset-color:  #fff; --tw-ring-color:  rgba(59,130,246,0.5); --tw-ring-offset-shadow:  0 0 #0000; --tw-ring-shadow:  0 0 #0000; --tw-shadow:  0 0 #0000; --tw-shadow-colored:  0 0 #0000; --tw-blur:  ; --tw-brightness:  ; --tw-contrast:  ; --tw-grayscale:  ; --tw-hue-rotate:  ; --tw-invert:  ; --tw-saturate:  ; --tw-sepia:  ; --tw-drop-shadow:  ; --tw-backdrop-blur:  ; --tw-backdrop-brightness:  ; --tw-backdrop-contrast:  ; --tw-backdrop-grayscale:  ; --tw-backdrop-hue-rotate:  ; --tw-backdrop-invert:  ; --tw-backdrop-opacity:  ; --tw-backdrop-saturate:  ; --tw-backdrop-sepia:  ; display: block; vertical-align: middle; left: 0px; top: 0px; width: 736px; height: 0px;"></iframe>

正则表达式`s*right`的`*`量词表示匹配s字符零次或者多次，即没有上限，可以是很多`sssss`。`'s*right'`给正则表达式使用单引号，也是避免shell解释特殊字符的方式。

```bash
echo right |  grep 's*right'
echo ssright |  grep 's*right'
```

以下是更高级的模式，它匹配所有以大写字母开头，以句点或逗号结尾的行。 `.*`正则表达式表示匹配任意数量的任何字符。

以下`grep`命令`-E`选项表示使用扩展正则表达式。`^`表示行的开始位置，`[A-Z]`表示A到大Z：

```bash
grep -E '^[A-Z].*[.,]$' file.txt
```

`?`使前一字符成为可选，并且只能匹配一次。以下grep命令将同时匹配`bright`和`right`。

你会这里的`?`字符的前面多了反斜杠。如果你使用的是基本正则表达式则需要反斜杠转义`?`字符避免shell的解释与执行。

```bash
grep 'b\?right' file.txt
```

以下`grep -E`是使用扩展正则表达式的方式匹配`'\b?right'`模式，因此不需要转义那些有特殊含义的字符。

```bash
grep -E 'b?right' file.txt
```

`+`字符与上一项匹配一次或多次。 以下将匹配`sright`和`ssright`，但不匹配`right`。

以下grep命令选项`-E` 表示使用扩展正则表达式，模式`'s+'` 表示必须存在一个`s`或者多个`s`字符，没有上限。

```bash
grep -E 's+right' file.txt
```

大括号字符`{}`允许您指定确切的数字，匹配次数必须在指定的范围内。以下grep命令将匹配3到9位数字的整数。

在以下`'[[:digit:]]{3,9}'`模式中，[:digit:]表示0到9的数字，`[[:digit:]]`则表示[0-9]，`{3,9}`表示匹配3到9次，即可行必须包含有3到9个连续的数字。

```bash
grep -E '[[:digit:]]{3,9}' file.txt
```

## 或运算

竖线`|`或运算符使您可以指定不同的可能匹配项，这些匹配项可以是文字字符串或正则表达式。在所有正则表达式运算符中，此运算符的优先级最低。

在下面的示例中，我们搜索[Nginx的错误日志文件](https://www.myfreax.com/nginx-log-files/)中出现单词`fatal`，`error`和`critical`行，如果使用扩展的正则表达式，则不需要对`|`进行转义。

```bash
grep 'fatal\|error\|critical' /var/log/nginx/error.log
grep -E 'fatal|error|critical' /var/log/nginx/error.log
```

## 分组

分组是正则表达式的一项功能，可让您将模式分组并将其作为引用。可使用括号`()`创建分组。使用基本正则表达式时，必须用反斜杠`\`对括号进行转义。

正则表达式可以有多个组。结果，匹配捕获的组通常保存在数组中，数组的成员与匹配的组顺序相同。这通常只是匹配组本身的顺序。

匹配的组保存在数组中，如果需要对捕获的组进行引用。可使用`$1, ..., $9`对捕获的组进行引用。

以下示例同时匹配`fear`和`less`。 量词`?`使`(fear)`组成为可选。

```bash
grep -E '(fear)?less' file.txt
```

## 反斜杠表达式

GNU `grep`包含几个由反斜杠和常规字符组成的元字符。以下是一些最常见的特殊反斜杠表达式。

`\b`匹配单词边界。`<`匹配单词开头的空字符串。`>`在单词末尾匹配一个空字符串。 `\w`匹配一个单词。`\s`匹配空格。

以下模式将匹配单独的单词`abject`和`object`。 如果嵌入较大的单词，则不会匹配这些单词：

```bash
grep '\b[ao]bject\b' file.txt
```

## 结论

正则表达式常用于文本编辑器，编程语言和命令行工具，例如`grep`，`sed`和`awk`。 在搜索文本文件，编写脚本或过滤命令输出时，知道如何构造正则表达式会非常有帮助。如果您有任何问题或反馈，请随时发表评论。