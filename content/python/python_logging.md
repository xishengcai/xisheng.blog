---
title: "python log"
date: 2019-10-26 T16:08:36+08:00
draft: false
---

[参考](https://juejin.im/post/5bc2bd3a5188255c94465d31)

### logging root

    root = RootLogger(WARNING)
    Logger.root = root
    Logger.manager = Manager(Logger.root)

    ?? root is interface
    
### init
```
class Logger(Filterer):
    def __init__(self, name, level=NOTSET):
        """
        Initialize the logger with a name and an optional level.
        """
        Filterer.__init__(self)
        self.name = name
        self.level = _checkLevel(level)
        self.parent = None
        self.propagate = 1
        self.handlers = []
        self.disabled = 0
```