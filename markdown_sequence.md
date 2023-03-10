

```sequence
title: 注释演示
participant A
note left of A: note 在A左边
```



```sequence
title: 注释演示
participant A
note over A: note 浮在A上
```



```sequence
title: 注释演示
participant A
participant B
participant C
participant D
note over A,D: note 跨过BC
```

```sequence
title: 注释演示
participant A
participant B
participant C
participant D
note over A,D: note 跨过BC
```

```sequence
title: 注释演示
participant A
participant B
A-->>B: 虚线空心演示
A-->B: 虚线实心演示
A->>B: 实线空心演示
A->B: 实线实心演示
```

```sequence
title:成员定义
participant Client
participant finefine as ff
participant kunkun as kk
ff->kk: say hello
ff->ff: say hello to my self
```

```sequence
title: Token Valid logic
participant Client as C
participant Server as S
C->S: 1.login with username and password
S->C: 2.response with token and something
note left of C: such as Android App、IOS\n App and so on.
note right of S: supply Api Service
C->S: 3.request data with token
S-->C: 4.response with data
C->>C: 5.hehe
note right of S: if token is valid then return\n the data that Client needed
note over C,S: This is the Token principle
```



## References

https://www.jianshu.com/p/70e329dd4a00