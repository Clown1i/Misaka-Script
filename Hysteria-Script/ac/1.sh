#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get -y update" "apt-get -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

IP=$(curl -s6m8 ip.sb) || IP=$(curl -s4m8 ip.sb)

if [[ -n $(echo $IP | grep ":") ]]; then
    IP="[$IP]"
fi

check_tun(){
    TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')
    if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then
        if [[ $vpsvirt == "openvz" ]]; then
            wget -N --no-check-certificate https://raw.githubusercontents.com/Misaka-blog/tun-script/master/tun.sh && bash tun.sh
        else
            red "检测到未开启TUN模块，请到VPS控制面板处开启"
            exit 1
        fi
    fi
}

checkCentOS8(){
    if [[ -n $(cat /etc/os-release | grep "CentOS Linux 8") ]]; then
        yellow "检测到当前VPS系统为CentOS 8，是否升级为CentOS Stream 8以确保软件包正常安装？"
        read -rp "请输入选项 [y/n]：" comfirmCentOSStream
        if [[ $comfirmCentOSStream == "y" ]]; then
            yellow "正在为你升级到CentOS Stream 8，大概需要10-30分钟的时间"
            sleep 1
            sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
            yum clean all && yum makecache
            dnf swap centos-linux-repos centos-stream-repos distro-sync -y
        else
            red "已取消升级过程，脚本即将退出！"
            exit 1
        fi
    fi
}

archAffix(){
    case "$(uname -m)" in
        i686 | i386) echo '386' ;;
        x86_64 | amd64) echo 'amd64' ;;
        armv5tel) echo 'arm-5' ;;
        armv7 | armv7l) echo 'arm-7' ;;
        armv8 | arm64 | aarch64) echo 'arm64' ;;
        s390x) echo 's390x' ;;
        *) red " 不支持的CPU架构！" && exit 1 ;;
    esac
    return 0
}

install_base() {
    if [[ $SYSTEM != "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} wget curl sudo
}

downloadHysteria() {
    rm -f /usr/bin/hysteria
    rm -rf /root/Hysteria
    mkdir /root/Hysteria
    ## last_version=$(curl -Ls "https://api.github.com/repos/HyNetwork/Hysteria/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    last_version=$(curl -Ls "https://data.jsdelivr.com/v1/package/resolve/gh/HyNetwork/Hysteria" | grep '"version":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ ! -n "$last_version" ]]; then
        red "检测 Hysteria 版本失败，可能是网络错误，请稍后再试"
        exit 1
    fi
    yellow "检测到 Hysteria 最新版本：${last_version}，开始安装"
    wget -N --no-check-certificate https://github.com/HyNetwork/Hysteria/releases/download/v${last_version}/Hysteria-tun-linux-$(archAffix) -O /usr/bin/hysteria
    if [[ $? -ne 0 ]]; then
        red "下载 Hysteria 失败，请确保你的服务器能够连接并下载 Github 的文件"
        exit 1
    fi
    chmod +x /usr/bin/hysteria
}

makeConfig() {
    read -rp "请输入 Hysteria 的连接端口（默认：40000）：" PORT
    [[ -z $PORT ]] && PORT=40000
    if [[ -n $(netstat -ntlp | grep "$PORT") ]]; then
        until [[ -z $(netstat -ntlp | grep "$PORT") ]]; do
            if [[ -n $(netstat -ntlp | grep "$PORT") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入 Hysteria 的连接端口（默认：40000）：" PORT
            fi
        done
    fi
    read -rp "请输入 Hysteria 的连接混淆密码（默认随机生成）：" OBFS
    [[ -z $OBFS ]] && OBFS=$(date +%s%N | md5sum | cut -c 1-32)
    sysctl -w net.core.rmem_max=4000000
    ulimit -n 1048576 && ulimit -u unlimited
    openssl ecparam -genkey -name prime256v1 -out /root/Hysteria/private.key
    openssl req -new -x509 -days 36500 -key /root/Hysteria/private.key -out /root/Hysteria/cert.crt -subj "/CN=www.bilibili.com"
    cat <<EOF > /root/Hysteria/server.json
{
    "listen": ":$PORT",
    "cert": "/root/Hysteria/cert.crt",
    "key": "/root/Hysteria/private.key",
    "obfs": "$OBFS"
}
EOF
    cat <<EOF > /root/Hysteria/client.json
{
    "server": "$IP:$PORT",
    "obfs": "$OBFS",
    "up_mbps": 200,
    "down_mbps": 1000,
    "insecure": true,
    "socks5": {
        "listen": "127.0.0.1:1080"
    },
    "http": {
        "listen": "127.0.0.1:1081"
    }
}
EOF
    cat <<EOF > /root/Hysteria/v2rayn.json
{
    "server": "$IP:$PORT",
    "obfs": "$OBFS",
    "up_mbps": 200,
    "down_mbps": 1000,
    "insecure": true,
    "acl": "acl/routes.acl",
    "mmdb": "acl/Country.mmdb",
    "retry": 3,
    "retry_interval": 5,
    "socks5": {
        "listen": "127.0.0.1:10808"
    },
    "http": {
        "listen": "127.0.0.1:10809"
    }
}
EOF
    cat <<'TEXT' > /etc/systemd/system/hysteria.service
[Unit]
Description=Hysiteria Server
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
WorkingDirectory=/root/Hysteria
ExecStart=/usr/bin/hysteria -c /root/Hysteria/server.json server
Restart=always
TEXT
    url="hysteria://$IP:$PORT?auth=$OBFS&upmbps=200&downmbps=1000&obfs=xplus&obfsParam=$OBFS"
}

installBBR() {
    result=$(lsmod | grep bbr)
    if [[ $result != "" ]]; then
        green "BBR模块已安装"
        return
    fi
    res=`systemd-detect-virt`
    if [[ $res =~ openvz|lxc ]]; then
        red "由于你的VPS为OpenVZ或LXC架构的VPS，跳过安装"
        return
    fi
    
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    result=$(lsmod | grep bbr)
    if [[ "$result" != "" ]]; then
        green "BBR模块已启用"
        return
    fi
    
    green "正在安装BBR模块..."
    if [[ $SYSTEM = "CentOS" ]]; then
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
        ${PACKAGE_INSTALL[int]} --enablerepo=elrepo-kernel kernel-ml
        ${PACKAGE_REMOVE[int]} kernel-3.*
        grub2-set-default 0
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    else
        ${PACKAGE_INSTALL[int]} --install-recommends linux-generic-hwe-16.04
        grub-set-default 0
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi
}

installHysteria() {
    checkCentOS8
    install_base
    downloadHysteria
    read -rp "是否安装BBR（y/n，默认n）：" INSTALL_BBR_YN
    if [[ $INSTALL_BBR_YN =~ "y"|"Y" ]]; then
        installBBR
    fi
    makeConfig
    systemctl enable hysteria
    systemctl start hysteria
    check_status
    if [[ -n $(service hysteria status 2>/dev/null | grep "inactive") ]]; then
        red "Hysteria 服务器安装失败"
    elif [[ -n $(service hysteria status 2>/dev/null | grep "active") ]]; then
        show_usage
        echo ""
        green "Hysteria 服务器已安装成功"
        yellow "服务器配置文件已保存到 /root/Hysteria/server.json"
        yellow "客户端配置文件已保存到 /root/Hysteria/client.json"
        yellow "V2rayN 带代理规则分流配置文件已保存到 /root/Hysteria/v2rayn.json"
        yellow "SagerNet / ShadowRocket 分享链接: "
        green "$url"
    fi
}

start_hysteria() {
    systemctl start hysteria
    green "Hysteria 已启动！"
}

stop_hysteria() {
    systemctl stop hysteria
    green "Hysteria 已停止！"
}

restart(){
    systemctl restart hysteria
    green "Hysteria 已重启！"
}

update_core(){
    current_version=$(hysteria -version 2>/dev/null | grep -oP "version v\K\S+")
    last_version=$(curl -Ls "https://data.jsdelivr.com/v1/package/resolve/gh/HyNetwork/Hysteria" | grep '"version":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ $last_version == $current_version ]]; then
        green "当前Hysteria内核已为最新版本，无需再次更新! "
    else
        systemctl stop hysteria
        rm -f /usr/bin/hysteria
        wget -N --no-check-certificate https://github.com/HyNetwork/Hysteria/releases/download/v${last_version}/Hysteria-tun-linux-$(archAffix) -O /usr/bin/hysteria
        if [[ $? -ne 0 ]]; then
            red "下载 Hysteria 失败，请确保你的服务器能够连接并下载 Github 的文件"
            exit 1
        fi
        chmod +x /usr/bin/hysteria
        systemctl start hysteria
    fi
}

view_log(){
    service hysteria status
}

uninstall(){
    systemctl stop hysteria
    systemctl disable hysteria
    rm -rf /root/Hysteria
    rm -f /usr/bin/hysteria /usr/local/bin/hy
    rm -f /etc/systemd/system/hysteria.service
    green "Hysteria 卸载完成！"
}

check_status(){
    if [[ -n $(service hysteria status 2>/dev/null | grep "inactive") ]]; then
        status="${RED}Hysteria 未启动！${PLAIN}"
    elif [[ -n $(service hysteria status 2>/dev/null | grep "active") ]]; then
        status="${GREEN}Hysteria 已启动！${PLAIN}"
    else
        status="${RED}未安装 Hysteria！${PLAIN}"
    fi
}

open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    green "放开VPS网络防火墙端口成功！"
}

closeipv6() {
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
    sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
    net.ipv6.conf.lo.disable_ipv6 = 1" >>/etc/sysctl.d/99-sysctl.conf
    sysctl --system
    green "禁用IPv6结束，可能需要重启！"
}

openipv6() {
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
    sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
    net.ipv6.conf.lo.disable_ipv6 = 0" >>/etc/sysctl.d/99-sysctl.conf
    sysctl --system
    green "开启IPv6结束，可能需要重启！"
}

show_usage(){
    echo "Hysteria 脚本快捷指令使用方法: "
    echo "------------------------------------------"
    echo "hy              - 显示管理菜单 (功能更多)"
    echo "hy install      - 安装 Hysteria"
    echo "hy uninstall    - 卸载 Hysteria"
    echo "hy on           - 启动 Hysteria"
    echo "hy off          - 关闭 Hysteria"
    echo "hy restart      - 重启 Hysteria"
    echo "hy update       - 更新 Hysteria"
    echo "hy log          - 查看 Hysteria 日志"
    echo "------------------------------------------"
}

menu() {
    clear
    check_status
    echo "#############################################################"
    echo -e "#                   ${RED}Hysteria  一键安装脚本${PLAIN}                  #"
    echo -e "# ${GREEN}作者${PLAIN}: Misaka No                                           #"
    echo -e "# ${GREEN}博客${PLAIN}: https://owo.misaka.rest                             #"
    echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
    echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/Misaka-blog                    #"
    echo -e "# ${GREEN}GitLab${PLAIN}: https://gitlab.com/misaka-blog                    #"
    echo -e "# ${GREEN}Bitbucket${PLAIN}: https://bitbucket.org/misakano7545             #"
    echo "#############################################################"
    echo ""
    echo -e "  ${GREEN}1.${PLAIN}  安装Hysieria "
    echo -e "  ${GREEN}2.  ${RED}卸载Hysieria ${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}3.${PLAIN}  启动Hysieria "
    echo -e "  ${GREEN}4.${PLAIN}  重启Hysieria "
    echo -e "  ${GREEN}5.${PLAIN}  停止Hysieria "
    echo -e "  ${GREEN}6.${PLAIN}  查看Hysieria日志 "
    echo " -------------"
    echo -e "  ${GREEN}7.${PLAIN}  启用IPv6 "
    echo -e "  ${GREEN}8.${PLAIN}  禁用IPv6 "
    echo -e "  ${GREEN}9.${PLAIN}  放行防火墙端口 "
    echo " -------------"
    echo -e "  ${GREEN}10.${PLAIN}  更新Hysteria内核版本"
    echo " -------------"
    echo -e "  ${GREEN}0.${PLAIN} 退出"
    echo ""
    echo -e "Hysteria 状态：$status"
    echo ""
    read -rp " 请选择操作[0-9]：" answer
    case $answer in
        1) installHysteria ;;
        2) uninstall ;;
        3) start_hysteria ;;
        4) restart ;;
        5) stop_hysteria ;;
        6) view_log ;;
        7) openipv6 ;;
        8) closeipv6 ;;
        9) open_ports ;;
        *) red "请选择正确的操作！" && exit 1 ;;
    esac
}

if [[ ! -f /usr/local/bin/hy ]]; then
    cp hysteria.sh /usr/local/bin/hy
    chmod +x /usr/local/bin/hy
fi

if [[ $# > 0 ]]; then
    case $1 in
        install ) installHysteria ;;
        uninstall ) uninstall ;;
        on ) start_hysteria ;;
        off ) stop_hysteria ;;
        restart ) restart ;;
        log ) view_log ;;
        update ) update_core ;;
        * ) show_usage ;;
    esac
else
    menu
fi