# 对 iOS Apps 打补丁以及重签名

##### 原文地址：[Patching and Re-Signing iOS Apps](http://www.vantagepoint.sg/blog/85-patching-and-re-signing-ios-apps)

##### 作者： Bernhard Mueller

##### 翻译： Chensh　　校对: 布兜儿



## 前言

在没有越狱的设备上运行经过修改的 iOS二进制文件，听起来是一个不错的主意，特别是当你的越狱机子变砖后，再更新为非越狱的 iOS 版本的时候（尽管我和我身边的人重来没遇到过这种事情）。你可以使用这种技术对 app 进行动态分析。又或者你可以做一个虚假的 GPS 定位欺骗来捕捉非洲地区锁定的 Pokemon，但又担心被发现。不管如何，你可以跟着下面的教程来修改一个 app 并且重签名，然后让它运行在你未越狱的设备上。注意这里的技术实现的前提条件是需要先砸壳，特别是来自 App Store 的 App。



由于苹果令人困扰的配置和代码签名系统，重签名一个 app 确实不是一项简单的挑战。app 的配置描述文件和代码签名头部需要完全一致，否则会被 iOS 系统拒绝运行。这就需要你学习很多相关的概念——证书、Bundle ID、应用 ID、团队标识符以及如何使用苹果的构建工具将他们绑定在一起。完全可以说，不使用 Xcode 这种默认方式去构建一个系统可以运行的特定的二进制文件，是一个大挑战。



我们将要使用的工具包括 [optool](https://github.com/alexzielenski/optool),苹果的构建工具以及一些 Shell 命令。这个方法中的重签脚本灵感来源于  [Vincent Tan's Swizzler project](https://github.com/vtky/Swizzler2/wiki)。另外可选择的不同的重打包使用工具在 [NCC group](https://www.nccgroup.trust/au/about-us/newsroom-and-events/blogs/2016/october/ios-instrumentation-without-jailbreak/)。



要复现以下步骤，请先下载 [UnCrackable iOS App Level 1](https://github.com/OWASP/owasp-mstg/blob/master/Crackmes/iOS/Level_01/UnCrackable_Level1.ipa),来自 OWASP 移动测试指南。我们的目标是使得 UnCrackable 这个 app 在启动的时候加载 FridaGadget.dylib 这个动态库，这样我们就能使用 Frida 来进行分析了。



## 获取一份开发者配置文件和证书

配置文件是是由苹果签名的、将一个或多个设备上的代码签名证书列入白名单的plist文件。就是说，苹果明确的要求你的应用运行在某一特性的环境里，例如在选定设备的调试模式下。配置文件还列出了你的应用拥有的权限，而代码签名证书里面包含了将要用于真实签名的私钥。

根据你是否已经注册为 iOS 开发者，你可以选择以下两种方式之一来获取证书和配置文件。



####  使用iOS开发者账号：

如果你之前曾使用 Xcode 开发和部署过 iOS 应用，那么你已经拥有了一个代码签名证书。使用 **security** 工具可以列出你当前存在的签名标志：



```shell
$ security find-identity -p codesigning -v
1) 61FA3547E0AF42A11E233F6A2B255E6B6AF262CE "iPhone Distribution: Vantage Point Security Pte. Ltd."
2) 8004380F331DCA22CC1B47FB1A805890AE41C938 "iPhone Developer: Bernhard Müller (RV852WND79)"
```



已注册开发者账号的开发者可用从苹果开发者网站获取配置文件，这里有份指南，可以指导第一次创建相应的证书和配置文件，[戳这里](https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistributionGuide/MaintainingProfiles/MaintainingProfiles.html)。对于重打包来说，并不特定要求你选择了什么应用 ID，你甚至可以重用一个已经存在的 ID。最重要的事情是拥有一份相匹配的配置文件。确保你创建了一份开发环境的配置文件，而不是一份分发配置文件，这样你才能对 app 进行调试。



在以下的 shell 命令列表中，我将会使用与我公司的开发团队相关联的个人签名身份。我创建了一个 app-id 为 "sg.vp.repackaged",以及取名为 "AwesomeRepackaging" 的配置文件，这便生成了一个名为 "AwesomeRepacaging.mobileprovision" 的配置文件 ——这里需要更换成你自己的 id 名和配置文件名。



#### 使用常规的 iTunes 账号：

虽然你不是一个付费开发者，但苹果还是提供了一个免费的开发者配置文件。你可以在 Xcode 里面使用你的 Apple 账号获取这个配置文件，只需简单的编译一个空的 iOS 工程，然后从 app 资源包里面提取出这个 **embedded.mobileprovision** 文件，具体可以参考 [NCC blog](https://www.nccgroup.trust/au/about-us/newsroom-and-events/blogs/2016/october/ios-instrumentation-without-jailbreak/) 的这篇博文。



当你获取到这个配置文件后，你可以使用 **security** 这个工具来查看它的内容。除了许可证书以及设备外，你还能在这个描述文件找到 app 的权限授权表。在之后的代码签名里面，你需要这个表，所以下面将演示如何将他们提取出来到一个 plist 格式的文件里。也可以查看文件的内容，是否跟预期一样。

```shell
$ security cms -D -i AwesomeRepackaging.mobileprovision > profile.plist
$ /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' profile.plist > entitlements.plist
$ cat entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>application-identifier</key>
<string>LRUD9L355Y.sg.vantagepoint.repackage</string>
<key>com.apple.developer.team-identifier</key>
<string>LRUD9L355Y</string>
<key>get-task-allow</key>
<true/>
<key>keychain-access-groups</key>
<array>
<string>LRUD9L355Y.*</string>
</array>
</dict>
</plist>
```



注意到我们的 App ID 是由团队标识符（LRUD9L355Y）以及 Bundle ID(sg.vantagepoint.repackage) 组合而成的。这个配置文件只对携带这样特定的 app id 才有效。 “get-task-allow” 这个键非常重要，当它为 true 时，才会允许其他进程（比如调试服务器）附加到应用程序，因此，在分发配置文件中应设置为 “false”。



#### 其他准备工作

为了在我们的 app 启动的时候加载一个附加的库，我们需要插入一条额外的加载命令到主程序的 Mach-O 头中。这里我们使用 [optool](https://github.com/alexzielenski/optool) 工具来自动化这个过程：

```shell
$ git clone https://github.com/alexzielenski/optool.git
$ cd optool/
$ git submodule update --init --recursive
```



我们也将使用到 [ios-deploy](https://github.com/phonegap/ios-deploy) 这个工具，这个工具能够在不使用 Xcode 的情况下发布或者调试 iOS 。（npm 是 Nodejs 的包管理器，如果你还没有安装 [Nodejs](https://nodejs.org/en/)，你可以使用 homebrew 来安装，或者到官网直接下载安装包）

```shell
$ npm install -g ios-deploy	
```



另外，在教程开始前，你还需要先把 FridaGadget.dylib 这个动态库下载下来。

```shell
$ curl -O https://build.frida.re/frida/ios/lib/FridaGadget.dylib
```



除了以上提到的工具，我们还需要使用一些原生系统工具和 Xcode 的编译工具，所以确保你已经安装了 Xcode 命令行开发工具。



#### 打补丁，重打包以及重签名

来不及了，快上车吧！

如你所知，IPA 文件其实一种ZIP压缩格式，所以我们可以使用 zip 工具来解压缩。然后将 **FridaGadget.dylib** 拷贝到文件目录下。并且使用 **optool** 工具将一条加载命令插入到 **UnCrackable Level 1** 这个二进制文件内。

```shell
$ unzip UnCrackable_Level1.ipa
$ cp FridaGadget.dylib Payload/UnCrackable\ Level\ 1.app/
$ optool install -c load -p "@executable_path/FridaGadget.dylib" -t Payload/UnCrackable\ Level\ 1.app/UnCrackable\ Level\ 1
Found FAT Header
Found thin header...
Found thin header...
Inserting a LC_LOAD_DYLIB command for architecture: arm
Successfully inserted a LC_LOAD_DYLIB command for arm
Inserting a LC_LOAD_DYLIB command for architecture: arm64
Successfully inserted a LC_LOAD_DYLIB command for arm64
Writing executable to Payload/UnCrackable Level 1.app/UnCrackable Level 1...
```



这种对主程序明显的篡改将会使得它的代码签名失效。所以这个无法在非越狱机子上运行。你需要替换掉配置文件，并使用描述文件中列举的证书对主程序和 FridaGadget.dylib 进行重新签名。

第一步，将我们的自己的配置文件拷贝到资源包里面：

```shell
$ cp AwesomeRepackaging.mobileprovision Payload/UnCrackable\ Level\ 1.app/embedded.mobileprovision\
```



第二步，我们需要确保在 **Info.plist** 中的 Bundle ID 是否跟我们的描述文件里面指定的一致。因为在重签的过程中，**codesign** 会检查我们的 Info.plist 文件里面的 Bundle ID，如果不匹配则会返回一个错误值。

```shell
$ /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier sg.vantagepoint.repackage" Payload/UnCrackable\ Level\ 1.app/Info.plist
```



最后，我们需要使用代码签名工具来重签所有的二进制文件：

```shell
$ rm -rf Payload/F/_CodeSignature
$ /usr/bin/codesign --force --sign 8004380F331DCA22CC1B47FB1A805890AE41C938 Payload/UnCrackable\ Level\ 1.app/FridaGadget.dylib
Payload/UnCrackable Level 1.app/FridaGadget.dylib: replacing existing signature
$ /usr/bin/codesign --force --sign 8004380F331DCA22CC1B47FB1A805890AE41C938 --entitlements entitlements.plist Payload/UnCrackable\ Level\ 1.app/UnCrackable\ Level\ 1
Payload/UnCrackable Level 1.app/UnCrackable Level 1: replacing existing signature
```



#### 安装并运行应用

现在你可以开始部署并运行修改后的 app 了，如下操作：

```shell
$ ios-deploy --debug --bundle Payload/UnCrackable\ Level\ 1.app/
```

如果一切顺利的话，app 应该会附加 **lldb** ，以调试模式运行在设备上。Frida 现在也附加到应用上了，可是使用 **frida-ps** 命令来验证一下：

```shell
$ frida-ps -U
PID Name
--- ------
499 Gadget
```

现在你可以使用 Frida 来正常调试你的应用了！



#### 故障排除

如果发生什么错误，有可能是配置文件和代码签名头不匹配，这种情况建议阅读一下[官方文档](https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistributionGuide/MaintainingProfiles/MaintainingProfiles.html)，了解一下整个系统是如何运行的。另外还可以参考[苹果授权故障排除](http://https//developer.apple.com/library/content/technotes/tn2415/_index.html)这个页面。



#### 关于这篇文件

这篇文章是 [Mobile Reverse Engineering Unleashed](safari-reader://www.vantagepoint.sg/blog/83-mobile-reverse-engineering-unleashed) 的系列之一。你可以访问[这里](http://www.vantagepoint.sg/blog/categories/17-mobile-reverse-engineering)来查看更多相关文章。

