# Xcode 编译提速



## Xcode 编译配置

### 输出文件的编译耗时

```shell
-Xfrontend -debug-time-function-bodies
```



### 输出编译总耗时

在终端中执行以下命令开启：

```shell
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES
```



### Xcode Build 时间概要统计

通过这样启动 Build: **Product -> Perform Action -> Build With Timing Summary**, 在 build 结束时，可以在 Xcode 的 Build 日志的末尾看到耗时概要统计。或者使用命令行：

```shell
xcodebuild -buildWithTimingSummary
```



## 提升 Swift 编译速度

### Swift 编译性能诊断选项

```shell
-driver-time-compilation
-Xfrontend -debug-time-function-bodies
-Xfrontend -debug-time-expression-type-checking
-Xfrontend -print-stats
-Xfrontend -print-clang-stats
-Xfrontend -print-stats -Xfrontend -print-inst-counts
```



### Swift 代码编译耗时分析

可以在 Xcode Build Settings 中的 `Other Swift Flags` 中加入诊断选项，将超过指定编译时长(如 100 毫秒)的函数、表达式以警告的方式显示出来，方便定位与优化：

```shell
-Xfrontend -warn-long-function-bodies=100
-Xfrontend -warn-long-expression-type-checking=100
```



## 参考

[提高编译速度的方法(swift)](https://krela2010.github.io/2020/10/22/2020-10-22-%E6%8F%90%E9%AB%98%E7%BC%96%E8%AF%91%E9%80%9F%E5%BA%A6%E7%9A%84%E6%96%B9%E6%B3%95(swift)/)

[LLVM学习](https://krela2010.github.io/2020/10/12/LLVM%E5%AD%A6%E4%B9%A0/)

[LLVM](http://www.aosabook.org/en/llvm.html)

[Apple: Improving the speed of incremental builds](https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds)

[GitHub: Build Time Analyzer for Xcode](https://github.com/RobertGummesson/BuildTimeAnalyzer-for-Xcode)

