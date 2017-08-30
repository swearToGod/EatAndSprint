# MMeTokenDecrypt

**原文链接：** [MMeTokenDecrypt](https://github.com/manwhoami/MMeTokenDecrypt)

**作者：** manwhoami

**翻译：**  Chensh　　**校对：**  布兜儿



## 前言

这个程序用来解密或提取出所有存储在 macOS/OS X/OSX 上面的授权令牌(Authorization Tokens)。无需用户身份验证，是因为利用了一个在 **macOS** 上授权访问钥匙串的流程中的缺陷。

所有的授权令牌都存储在 `/Users/*/Library/Application Support/iCloud/Accounts/DSID` 目录下。 DSID 是每一个 iCloud 账户在苹果系统里的后端存储格式。

这个 **DSID** 格式文件使用了**128位AES的CBC模式**[^注1] 和一个空的**初始化向量**进行加密。针对这个文件的解密密钥存储在用户的**钥匙串**里，一个名为 **iCloud** 的服务条目下，名字是 iCloud 账户相关的邮件地址。

这个解密钥匙进行了 base64 编码，并作为 **Hmac 算法**[^注2]中的消息体，进行标准的 **MD5 哈希加密**。这里的问题是，Hmac 算法里所需的输入钥匙，被藏在了 **MacOS 内核**深处。这个钥匙由44个随机字符组成，它是解密 DSID 文件的关键。这个钥匙包含在本工程的源代码中，据我所知，到目前为止这个钥匙还未被公开过。



## 意义

目前市面上拥有类似功能的工具，只有一款名为 “**Elcomsoft Phone Breaker** [^注3]”的取证工具。 MMeTokenDecrypt 是开源的，允许任何开发者在工程里使用这个解密 iCloud 授权的文件。

苹果必须要重新设计钥匙串信息的获取方式。因为本程序 fork 了一个苹果已经签名的二进制文件作为子进程，当用户看到钥匙串访问请求弹窗时，并不会意识到其背后的危险。更进一步，攻击者可以向用户重复弹出钥匙串弹窗，直至用户允许了钥匙串访问为止，因为苹果并没有为拒绝选项设定超时时间。这将会导致iCloud授权令牌被盗窃，而这些令牌可以用来访问几乎所有iCloud的服务项目：**iOS备份，iCloud联系人，iCloud Drive， iCloud 图片库， 查找我的好友，查找我的手机（查看我其他的项目）**。



## 上报反馈历程

* 我2016年10月17日开始联系苹果，非常详细地阐述了如何破坏用户钥匙串授权的方法，并在不同的 macOS 系统版本中进行重现。
* 直到2016年11月6日，没有得到苹果的任何反馈。(委屈😢失落的作者……)
* bug报告包含了破坏整个钥匙串访问。MMeTokenDecrypt 只是这个 bug 的其中一个实现。查看我的其他项目，**OSXChromeDecrypt** 是这个 bug 的另外一种实现。
* 报告中有个值得注意的摘录如下：

> 此外，假如我们是远程攻击者，当“询问钥匙串密码”的选项没有被勾选时，那么本质上，我们就是通过代码实现强制弹窗提示，迫使用户单击“允许”按钮，这样我们就可以获得密码。但是，如果“通过密码访问钥匙串”的选项被选中，并且用户点击了“拒绝”按钮，那么强制提示则会变得比较棘手。

* 我已经把 bug 的报告上传到本项目中，并将实时同步苹果的更新。



## 用法

运行 python 文件：

```shell
$ python MMeDecrypt.py
```

```Shell
Decrypting token plist -> [/Users/bob/Library/Application Support/iCloud/Accounts/123456789]

Successfully decrypted token plist!

bobloblaw@gmail.com Bob Loblaw -> [123456789]

cloudKitToken = AQAAAABYXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~

mapsToken = AQAAAAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~

mmeAuthToken = AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=

mmeBTMMInfiniteToken = AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~

mmeFMFAppToken = AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~

mmeFMIPToken = AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~
```



## 注意

假如你是使用 homebrew 安装的 python，那么你运行这个脚本的时候有可能会遇到以下错误：

```shell
user@system:~/code/MMeTokenDecrypt $ python MMeDecrypt.py
Traceback (most recent call last):
  File "MMeDecrypt.py", line 2, in <module>
    from Foundation import NSData, NSPropertyListSerialization
ImportError: No module named Foundation
```



想要解决这个问题，你可以手动指定一个你系统上默认的 python 版本的完整的路径。

```shell
user@system:~/code/MMeTokenDecrypt $ /usr/bin/python MMeDecrypt.py
Decrypting token plist -> [/Users/user/Library/Application Support/iCloud/Accounts/123413453]

Successfully decrypted token plist!

user@email.com [First Last -> 123413453]
{
    cloudKitToken = "AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~";
    mapsToken = "AQAAAAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~";
    mmeAuthToken = "AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
    mmeBTMMInfiniteToken = "AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~";
    mmeFMFAppToken = "AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~";
    mmeFMIPToken = "AQAAAABXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~";
}
```



**已在 Mac OS X EI Capitan 上验证**



## 注释

**注1：**  AES 的 CBC 加密模式。即为密码分组链接模式（Cipher Block Chaining (CBC)），这种模式是先将明文切分成若干小段，然后每一小段与初始块或者上一段的密文段进行异或运算后，再与密钥进行加密。

**注2：** Hmac 算法，是密钥相关的哈希运算消息认证码，HMAC运算利用哈希算法，以一个密钥和一个消息为输入，生成一个消息摘要作为输出。

**注3：** [Elcomsoft Phone Breaker](https://www.elcomsoft.com/eppb.html) 是 Elcomsoft 公司的一款手机取证工具，具有解密、下载 iCloud 文件和备份，获取 iCloud 的 Token，解析钥匙串等功能。



## 以下内容是我发送给苹果的Bug报告

* 日期：2016年10月17日

**概要：**

致相关人士，

目前将程序插入到 MacOS/OS X （每个版本）中的条目的实现，都缺乏一个关键的特性。

这个特性其实早已可以通过钥匙串访问程序来实现，但由于某些原因，迟迟没有开放给 **“security”** 命令行工具。

在**钥匙串访问 app** 中“访问控制”下的**“询问钥匙串密码”**选项实现了这样的功能。

但它不允许开发者使用程序来自动勾选这个选项，这种做法阻止了开发者安全地将数据信息存储到钥匙串中。

因为应用开发者并不能仅针对他们的应用或者合法的钥匙串所有者来限制钥匙串条目的访问。



例如，假设有人未经允许访问了我的电脑，然后想要获取到钥匙串里面Chrome安全存储条目中的键值，那么他所需要做的就是允许一个命令：**secutiry find-generic-password -ga 'Chrome'**.

而之后那些恶意用户所需要做的，仅仅是在弹出钥匙串弹窗点击**“允许”**按钮。

但是，如果本机主人以前曾经打开过钥匙串访问，在 Chrome 安全存储条目中的访问控制面板下，勾选过**“询问钥匙串密码”**的选项，那么就可以强制恶意用户必须输入钥匙串密码，否则未授权的访问将会被终止。

谷歌 Chrome 依旧可以无限制地访问这个钥匙串（这也是我们所希望的），因为它在访问控制面板下被列为了唯一授权应用。

此外，假如我们是远程攻击者，当“询问钥匙串密码”的选项没有被勾选，那么我们本质上就是通过代码实现强制弹窗提示，迫使用户单击“允许”按钮，这样我们就可以获得密码。

但是，如果“通过密码访问钥匙串”的选项被选中，并且用户点击了“拒绝”按钮，那么强制提示则会变得比较棘手。(参见参考文献)



**重现步骤：**

1. 谷歌 Chrome 浏览器是一个很好的例子，因为它是一个很常用的应用，而且可以非常直接查看到它通过 MacOS 系统或调用库创建的钥匙串条目。
2. 在我们勾选钥匙串访问面板中的“询问钥匙串密码”选项之前。我们先在命令行运行以下命令：**secutiry find-generic-password -ga 'Chrome'**，然后我们可以观察到，这些敏感信息非常需要钥匙串密码来验证以保证安全性。（这个安全存储键值可以解密谷歌 Chrome 所有本地存储的密码）
3. 在钥匙串访问中，查找到“Chrome Safe Storage”条目，右键，显示简介，切换到访问控制面板，勾选“询问钥匙串密码”选项，然后保存更改。（这里钥匙串应用有个Bug，就是你需要重复这个操作两次才能够真正生效。但这个是无关本次议题的bug了）
4. 当我们使用命令**“security add-generic-password -T | -A”**来创建一个新的钥匙串密码条目后，打开谷歌Chrome浏览器，发现它并没有询问你确认你的密码，这是因为它已经是在受信任列表里面的应用了。
5. 在命令行下，我们再次运行**secutiry find-generic-password -ga 'Chrome'**这个命令，我们发现这次的弹窗需要你输入密码了。

**预期结果：**
在这些步骤之后，您将了解到为何密码是必需。    

**实际结果：**
如上所述。

**版本：**
所有的 MacOS 或 OSX 版本。     

**注意：**
在 MacOS 中已经存在“询问钥匙串密码”的选项功能了。

实现这点只需要很少的资源。

我在此请求苹果开放程序控制这个功能给开发者（IE将新的条目参数添加到钥匙串的操作是：**‘security add-generic-password -T | -A’**），以便终止那些未经许可的钥匙串信息访问。

因此，希望把勾选“询问钥匙串密码”后的系统调用加入到 “security” 这个命令行工具的调用里面，提供一个参数允许开发者通过命令行工具去设置选项是否选中，而不是通过用户交互界面。

作为一个应用开发者，我不能指望我的用户通过 GUI 操作来保护我的应用里面的钥匙串条目。毕竟应用开发者的一个目标就是减少用户的繁琐操作。