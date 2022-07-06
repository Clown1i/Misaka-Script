#!/bin/bash

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
} 
green() {
    echo -e "\033[32m\033[01m$1\033[0m"
} 
yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
} 

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')") 

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持当前VPS的系统，请使用主流操作系统" && exit 1
[[ -z $(type -P wg-quick) ]] && red "Wgcf-WARP代理模式未安装，脚本即将退出！" && rm -f netfilx4.sh && exit 1

check(){
    NetfilxStatus=$(curl -4 --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36 Edg/99.0.1150.39" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81215567" 2>&1)
    if [[ $NetfilxStatus == "200" ]]; then
        success
    fi
    if [[ $NetfilxStatus =~ "403"|"404" ]]; then
        failed  
    fi
    if [[ -z $NetfilxStatus ]] || [[ $NetfilxStatus == "000" ]]; then
        retry
    fi
}

retry(){
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

success(){
    WgcfWARPIP=$(curl -s4m8 https://ip.gs -k)
    green "当前Wgcf-WARP的IP：$WgcfWARPIP 已解锁Netfilx"
    yellow "等待1小时后，脚本将会自动重新检查Netfilx解锁状态"
    sleep 1h
    check
}

failed(){
    WgcfWARPIP=$(curl -s4m8 https://ip.gs -k)
    red "当前Wgcf-WARP的IP：$WgcfWARPIP 未解锁Netfilx，脚本将在15秒后重新测试Netfilx解锁情况"
    sleep 15
    wg-quick down wgcf >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    check
}

check
