# MacOS Commands



## Reset app permissions

- ` tccutil reset Camera`

- ` tccutil reset Microphone`

- `tccutil reset ScreenCapture`

- ` tccutil reset All `

- `tccutil reset All app-bundle-id`

  app-bundle-id: eg, com.evanxlh.myapp



## List folder size

- `du -d 1 -h`

- `du -hs *`

  

## List process openned files

```shell
lsof -p pid
```

`pid` is the process id, it's an integer, like **8976**. 

[macOS too many open files](https://blog.abreto.net/archives/2020/02/macos-too-many-open-files.html)



## Change dynamic library version dependancy

- List library dependancy

  `otool -L YourDynamicLibraryFilePath`

- Change version

  ```shell
  install_name_tool -change @rpath/DependantLibName.1.0.dylib @rpath/DependantLibName.2.0.dylib YourLibName.dylib
  ```



