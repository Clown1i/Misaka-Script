#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

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
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")

# 判断系统CPU架构
cpuArch=$(uname -m)

# 判断是否为root用户
[[ $EUID -ne 0 ]] && yellow "请在root用户下运行脚本" && exit 1

# 检测系统，本部分代码感谢fscarmen的指导
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
	SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
	[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持VPS的当前系统，请使用主流的操作系统" && exit 1
[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int} && ${PACKAGE_INSTALL[int]} curl

checkCentOS8() {
	if [[ -n $(cat /etc/os-release | grep "CentOS Linux 8") ]]; then
		yellow "检测到当前VPS系统为CentOS 8，是否升级为CentOS Stream 8以确保软件包正常安装？"
		read -p "请输入选项 [y/n]：" comfirmCentOSStream
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

archAffix() {
	case "$cpuArch" in
		i686 | i386) cpuArch='386' ;;
		x86_64 | amd64) cpuArch='amd64' ;;
		armv5tel | arm6l | armv7 | armv7l) cpuArch='arm' ;;
		armv8 | arm64 | aarch64) cpuArch='aarch64' ;;
		*) red "不支持的CPU架构！" && exit 1 ;;
	esac
}

back2menu() {
	green "所选操作执行完成"
	read -p "请输入“y”退出，或按任意键回到主菜单：" back2menuInput
	case "$back2menuInput" in
		y) exit 1 ;;
		*) menu ;;
	esac
}

checkStatus() {
	[[ -z $(cloudflared -help 2>/dev/null) ]] && cloudflaredStatus="未安装"
	[[ -n $(cloudflared -help 2>/dev/null) ]] && cloudflaredStatus="已安装"
	[[ -f /root/.cloudflared/cert.pem ]] && loginStatus="已登录"
	[[ ! -f /root/.cloudflared/cert.pem ]] && loginStatus="未登录"
}

installCloudFlared() {
	[[ $cloudflaredStatus == "已安装" ]] && red "检测到已安装并登录CloudFlare Argo Tunnel，无需重复安装！！" && exit 1
	wget -N --no-check-certificate https://github.com/cloudflare/cloudflared/releases/download/2022.5.3/cloudflared-linux-$cpuArch -O /usr/local/bin/cloudflared
	chmod +x /usr/local/bin/cloudflared
}

loginCloudFlared(){
	[[ $loginStatus == "已登录" ]] && red "检测到已登录CloudFlare Argo Tunnel，无需重复登录！！" && exit 1
	cloudflared tunnel login
	checkStatus
	if [[ $cloudflaredStatus == "未登录" ]]; then
		red "登录CloudFlare Argo Tunnel失败！！"
		back2menu
	else
		green "登录CloudFlare Argo Tunnel成功！！"
		back2menu
	fi
}

uninstallCloudFlared() {
	[[ $cloudflaredStatus == "未安装" ]] && red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！" && exit 1
	rm -f /usr/local/bin/cloudflared
	rm -rf /root/.cloudflared
	yellow "CloudFlared 客户端已卸载成功"
}

listTunnel() {
	[[ $cloudflaredStatus == "未安装" ]] && red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！" && exit 1
	[[ $loginStatus == "未登录" ]] && red "请登录CloudFlare Argo Tunnel客户端后再执行操作！！！" && exit 1
	cloudflared tunnel list
	back2menu
}

makeTunnel() {
	read -p "请输入需要创建的隧道名称：" tunnelName
	cloudflared tunnel create $tunnelName
	read -p "请输入域名：" tunnelDomain
	cloudflared tunnel route dns $tunnelName $tunnelDomain
	cloudflared tunnel list
	# 感谢yuuki410在其分支中提取隧道UUID的代码
	# Source: https://github.com/yuuki410/argo-tunnel-script
	tunnelUUID=$( $(cloudflared tunnel list | grep $tunnelName) = /[0-9a-f\-]+/)
	read -p "请输入隧道UUID（复制ID里面的内容）：" tunnelUUID
	read -p "请输入传输协议（默认http）：" tunnelProtocol
	[[ -z $tunnelProtocol ]] && tunnelProtocol="http"
	read -p "请输入反代端口（默认80）：" tunnelPort
	[[ -z $tunnelPort ]] && tunnelPort=80
	read -p "请输入保存的配置文件名（默认：$tunnelFileName）：" tunnelFileName
	[[ -z $tunnelFileName ]] && tunnelFileName = $tunnelName
	cat <<EOF > ~/$tunnelFileName.yml
tunnel: $tunnelName
credentials-file: /root/.cloudflared/$tunnelUUID.json
originRequest:
  connectTimeout: 30s
  noTLSVerify: true
ingress:
  - hostname: $tunnelDomain
    service: $tunnelProtocol://localhost:$tunnelPort
  - service: http_status:404
EOF
	green "配置文件已保存至 /root/$tunnelFileName.yml"
	back2menu
}

runTunnel() {
	[[ $cloudflaredStatus == "未安装" ]] && red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！" && exit 1
	[[ $loginStatus == "未登录" ]] && red "请登录CloudFlare Argo Tunnel客户端后再执行操作！！！" && exit 1
	[[ -z $(type -P screen) ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} screen
	read -p "请复制粘贴配置文件的位置（例：/root/tunnel.yml）：" ymlLocation
	read -p "请输入创建Screen会话的名字：" screenName
	screen -USdm $screenName cloudflared tunnel --config $ymlLocation run
	green "隧道已运行成功，请等待1-3分钟启动并解析完毕"
	back2menu
}

killTunnel() {
	[[ $cloudflaredStatus == "未安装" ]] && red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！" && exit 1
	[[ $loginStatus == "未登录" ]] && red "请登录CloudFlare Argo Tunnel客户端后再执行操作！！！" && exit 1
	[[ -z $(type -P screen) ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} screen
	read -p "请输入需要删除的Screen会话名字：" screenName
	screen -S $screenName -X quit
	green "Screen会话停止成功！"
	back2menu
}

deleteTunnel() {
	[[ $cloudflaredStatus == "未安装" ]] && red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！" && exit 1
	[[ $loginStatus == "未登录" ]] && red "请登录CloudFlare Argo Tunnel客户端后再执行操作！！！" && exit 1
	read -p "请输入需要删除的隧道名称：" tunnelName
	cloudflared tunnel delete $tunnelName
	back2menu
}

argoCert() {
	[[ $cloudflaredStatus == "未安装" ]] && red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！" && exit 1
	[[ $loginStatus == "未登录" ]] && red "请登录CloudFlare Argo Tunnel客户端后再执行操作！！！" && exit 1
	sed -n "1, 5p" /root/.cloudflared/cert.pem >>/root/private.key
	sed -n "6, 24p" /root/.cloudflared/cert.pem >>/root/cert.crt
	green "CloudFlare Argo Tunnel证书提取成功！"
	yellow "证书crt路径如下：/root/cert.crt"
	yellow "私钥key路径如下：/root/private.key"
	green "使用证书提示："
	yellow "1. 当前证书只能使用于CF Argo Tunnel授权过的域名"
	yellow "2. 在需要使用证书的服务使用Argo Tunnel的域名，必须使用其证书"
	back2menu
}

menu() {
	checkStatus
	clear
	echo "#############################################################"
	echo -e "#           ${RED}CloudFlare Argo Tunnel 一键配置脚本${PLAIN}             #"
	echo -e "# ${GREEN}作者${PLAIN}: Misaka No                                           #"
	echo -e "# ${GREEN}网址${PLAIN}: https://owo.misaka.rest                             #"
	echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
	echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
	echo "#############################################################"
	echo ""
	echo -e " ${GREEN}1.${PLAIN} 安装 CloudFlare Argo Tunnel"
	echo -e " ${GREEN}2.${PLAIN} 登录 CloudFlare Argo Tunnel"
	echo -e " ${GREEN}3.${PLAIN} ${RED}卸载 CloudFlare Argo Tunnel${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}4.${PLAIN} 查看账户内 Argo Tunnel 列表"
	echo " -------------"
	echo -e " ${GREEN}5.${PLAIN} 创建 Argo Tunnel 隧道"
	echo -e " ${GREEN}6.${PLAIN} 运行 Argo Tunnel 隧道"
	echo -e " ${GREEN}7.${PLAIN} 停止 Argo Tunnel 隧道"
	echo -e " ${GREEN}8.${PLAIN} ${RED}删除 Argo Tunnel 隧道${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}9.${PLAIN} 提取 Argo Tunnel 证书"
	echo -e " ${GREEN}0.${PLAIN} 退出脚本"
	echo ""
	echo -e "CloudFlared 客户端状态：$cloudflaredStatus   账户登录状态：$loginStatus"
	echo -e "今日运行次数：$TODAY   总共运行次数：$TOTAL"
	echo ""
	read -rp "请输入选项 [0-9]: " menuChoice
	case $menuChoice in
		1) installCloudFlared ;;
		2) loginCloudFlared ;;
		3) uninstallCloudFlared ;;
		4) listTunnel ;;
		5) makeTunnel ;;
		6) runTunnel ;;
		7) killTunnel ;;
		8) deleteTunnel ;;
		9) argoCert ;;
		*) exit 1 ;;
	esac
}

archAffix
checkCentOS8
menu
