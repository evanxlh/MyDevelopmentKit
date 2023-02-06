# Git Commands



[Git Manual](https://evanxlh.github.io/2020/06/29/git-manual/)

## Push commit to multiple git repositories

If you have a github project, and you also want to push the changes to gitee, you can do like this:

```shell
git remote set-url --add origin git@gitee.com:evanxlh/MyDevelopmentKit.git
```

then, you can push the changes also to your new binded repository.

 Use `git remote -v`, you will see:

```shell
origin	git@github.com:evanxlh/MyDevelopmentKit.git (fetch)
origin	git@github.com:evanxlh/MyDevelopmentKit.git (push)
origin	git@gitee.com:evanxlh/MyDevelopmentKit.git (push)
```



## Branch Operations

### Prune branches 

Delete branches from local, which are removed from remote repositry.

 ```shell
 git remote prune origin
 ```



### Delete remote branch

```shell
git push origin --delete YourRemoteBranchName
```



