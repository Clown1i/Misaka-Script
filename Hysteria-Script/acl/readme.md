# Source: https://github.com/emptysuns/Hi_Hysteria

## 生成hysteria的代理直连规则+反广告

由于直接用网段判断代理时，dns污染后返回的ip也属于大陆ip，会导致无法代理，所以加入域名列表，顺手加上antiAD

```shell
# 生成routes.acl
> python3 GetRoutes.py
Generate complete.
```
