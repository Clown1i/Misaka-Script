# Hysteria-script

Hysteria 一键脚本，支持IPv4、IPv6 VPS

> 注意⚠：部分VPS提供商会对部署Hysteria的VPS实例实行封号等处理策略，请谨慎部署和使用！

## 使用方法

```shell
wget -N https://raw.githubusercontent.com/Clown1i/Misaka-Script/main/Hysteria-Script/hysteria.sh && bash hysteria.sh
```

### 快捷指令

|  命令   | 备注 |
|  ----  | ---- |
| hy | 脚本管理菜单 |
| hy install | 安装 Hysteria |
| hy uninstall | 卸载 Hysteria |
| hy on | 启动 Hysteria |
| hy off | 关闭 Hysteria |
| hy restart | 重启 Hysteria |
| hy log | 查看 Hysteria 日志 |

## 脚本预览

![image](https://user-images.githubusercontent.com/96560028/169633663-41807686-9284-4ce9-819d-74652957f038.png)

![image](https://user-images.githubusercontent.com/96560028/169633677-ec8243a1-b005-4265-8d98-5858a2f33c0c.png)

## 客户端连接教程

新版V2rayN: https://owo.misaka.rest/Hysteria-V2rayN/

### 官方命令行连接教程

1. 在 Hysteria 的 [Release 页面](https://github.com/HyNetwork/hysteria/releases)，根据自己的架构下载对应的程序

![image](https://user-images.githubusercontent.com/96560028/167276169-c24e2db7-7e39-45dc-aba9-127f1a48f01a.png)

2. 把脚本生成的 `client.json` 和 Hysteria 主程序放到同一目录下

![image](https://user-images.githubusercontent.com/96560028/167276200-f4e3cbd5-ce26-481b-9a55-cd159a92385d.png)

3. 打开命令行，输入以下命令（以Windows为例）

```bat
.\hysteria-tun-windows-6.0-amd64.exe -c client.json client
```

4. 如图所示，即可代表 Hysteria 客户端已成功运行。**切记不能直接关闭！！！**

![image](https://user-images.githubusercontent.com/96560028/167276127-2a2f7693-3d08-4a1e-a5ba-8031a8a4c4b2.png)

5. 在 V2rayN 上添加一个 Socks5 节点，然后使用 V2rayN 连接

![image](https://user-images.githubusercontent.com/96560028/167276239-9d4b9fbf-8b97-43ea-8313-96ad05ead039.png)

## 带宽设置优化建议

在生成的`client.json`文件中，`up_mbps`为上传速度，`down_mbps`为下载速度

建议设置如下：

上传速度：本地宽带速率 / 5

下载速度：本地宽带速率

![image](https://user-images.githubusercontent.com/96560028/169646250-605e05ac-78ed-41f3-9ea9-942ba26a151e.png)

## 参考资料

Hysteria：https://github.com/HyNetwork/hysteria

YouTube 不良林：https://www.youtube.com/watch?v=pMe_oErfLWQ

## 交流

[Telegram 群组](https://t.me/misakanetcn)
