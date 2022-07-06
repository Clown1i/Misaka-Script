# CloudFlare Argo Tunnel 一键配置脚本

白嫖CloudFlare的Argo Tunnel隧道，实现内网穿透！！！目前脚本支持Argo Tunnel[支持的协议](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress)的穿透，并保存为CloudFlare Argo Tunnel的配置文件；默认使用Screen运行隧道，让你断开SSH也可以无限链接！！

如对脚本不放心，可使用此沙箱先测一遍再使用：https://killercoda.com/playgrounds/scenario/ubuntu

## 使用方法

```shell
wget -N --no-check-certificate https://raw.githubusercontents.com/Misaka-blog/argo-tunnel-script/master/argo.sh && bash argo.sh
```

快捷方式 `bash argo.sh`

## CloudFlare Argo Tunnel TCP 协议连接教程

1. 下载并安装[cloudflared客户端](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation)
2. 命令行输入以下指令

```bat
cloudflared access tcp --hostname [绑定到的域名] --listener [本地监听地址]
```

例如：`cloudflared access tcp --hostname cgss.example.com --listener 127.0.0.1:35565`，将绑定到cgss.example.com的隧道映射到本地的35565端口

## 参考资料

CloudFlare Argo Tunnel: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation

苍穹の下 · SKY的Blog：https://www.blueskyxn.com/202102/4176.html

Booker——知识博客：https://www.dll3.cn/534.html

lxxself: https://lxx.im/cloudflare-tunnel

yuuki410 fork的分支：https://github.com/yuuki410/argo-tunnel-script

## 交流群

[Telegram](https://t.me/misakanetcn)

## 赞助我们

![afdian-MisakaNo.jpg](https://s2.loli.net/2021/12/25/SimocqwhVg89NQJ.jpg)
