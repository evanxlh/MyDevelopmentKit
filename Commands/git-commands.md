# Git 常用命令

[Git Manual](https://evanxlh.github.io/2020/06/29/git-manual/)

## 将修改提交到多个Git 仓库

如果你的项目同时存放在 GitHub 和 Gitee,  您可以把远程仓库地址添加下:

```shell
git remote set-url --add origin git@gitee.com:evanxlh/MyDevelopmentKit.git
```

 使用 `git remote -v`,  就可以看到您绑定的远程仓库的址址了：

```shell
origin	git@github.com:evanxlh/MyDevelopmentKit.git (fetch)
origin	git@github.com:evanxlh/MyDevelopmentKit.git (push)
origin	git@gitee.com:evanxlh/MyDevelopmentKit.git (push)
```

最后使用 `git push` , 就可以将你的提交同时推送到这两个远程仓库。



## 分支操作

### 同步Git远程仓库删除的分支 

将远程仓库已删除的分支，在本地也删除.

 ```shell
 git remote prune origin
 ```



### 删除远程分支

```shell
git push origin --delete YourRemoteBranchName
```



## 提交

### 修改最后一个提交的 message

```shell
git commit --amend --message="new message"
```



## 恢复

有时候会因为一些意外，导致提交内容丢失。遇到这种情况也不用慌，只要您曾经提交过，就可以找回：

1. 使用 `git reflog ` 列出最近的提交
2. 然后使用 `git reset --hard YOUR_COMMIT_ID` , 即可找回丢失的 commit。但在这步操作之前，做好原有代码的备份。