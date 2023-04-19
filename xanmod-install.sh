#!/bin/bash

# 需要安装的xanmod版本
unset install_package

# 需要安装的软件包
unset install_packages

unset x86_64_psabi_version

xanmod_source_preinstalled=0

#功能性函数：
#定义几个颜色
purple()                           #基佬紫
{
    echo -e "\\033[35;1m${*}\\033[0m"
}
tyblue()                           #天依蓝
{
    echo -e "\\033[36;1m${*}\\033[0m"
}
green()                            #原谅绿
{
    echo -e "\\033[32;1m${*}\\033[0m"
}
yellow()                           #鸭屎黄
{
    echo -e "\\033[33;1m${*}\\033[0m"
}
red()                              #姨妈红
{
    echo -e "\\033[31;1m${*}\\033[0m"
}
blue()                             #蓝色
{
    echo -e "\\033[34;1m${*}\\033[0m"
}
#检查基本命令
check_base_command()
{
    hash -r
    local i
    local temp_command_list=('bash' 'sh' 'command' 'type' 'hash' 'install' 'true' 'false' 'exit' 'echo' 'test' 'sort' 'sed' 'awk' 'grep' 'cut' 'cd' 'rm' 'cp' 'mv' 'head' 'tail' 'uname' 'tr' 'md5sum' 'cat' 'find' 'wc' 'ls' 'mktemp' 'swapon' 'swapoff' 'mkswap' 'chmod' 'chown' 'chgrp' 'export' 'tar' 'gzip' 'mkdir' 'arch' 'uniq' 'dd' 'env')
    for i in "${temp_command_list[@]}"
    do
        if ! command -V "${i}" > /dev/null; then
            red "命令\"${i}\"未找到"
            red "不是标准的Linux系统"
            exit 1
        fi
    done
}
#安装单个重要依赖
test_important_dependence_installed()
{
    local temp_exit_code=1
    if LANG="en_US.UTF-8" LANGUAGE="en_US:en" dpkg -s "$1" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$'; then
        if LANG="en_US.UTF-8" LANGUAGE="en_US:en" apt-mark manual "$1" | grep -qi 'set[ '$'\t]*to[ '$'\t]*manually[ '$'\t]*installed'; then
            temp_exit_code=0
        else
            red "安装依赖 \"$1\" 出错！"
            green  "欢迎进行Bug report(https://github.com/kirin10000/xanmod-install/issues)，感谢您的支持"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
        fi
    elif $apt_no_install_recommends -y install "$1"; then
        temp_exit_code=0
    else
        $apt update
        $apt_no_install_recommends -y -f install
        $apt_no_install_recommends -y install "$1" && temp_exit_code=0
    fi
    return $temp_exit_code
}
check_important_dependence_installed()
{
    if ! test_important_dependence_installed "$@"; then
        red "重要组件\"$1\"安装失败！！"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
ask_if()
{
    local choice=""
    while [ "$choice" != "y" ] && [ "$choice" != "n" ]
    do
        tyblue "$1"
        read choice
    done
    [ $choice == y ] && return 0
    return 1
}

check_base_command
if [[ "$(type -P apt)" ]] || [ "$(type -P apt-get)" ]; then
    if [[ "$(type -P dnf)" ]] || [[ "$(type -P microdnf)" ]] || [[ "$(type -P yum)" ]]; then
        red "同时存在 apt/apt-get 和 dnf/microdnf/yum"
        red "不支持的系统！"
        exit 1
    fi
    release="other-debian"
    if [[ "$(type -P apt)" ]]; then
        apt="apt"
    else
        apt="apt-get"
    fi
    apt_no_install_recommends="$apt --no-install-recommends"
else
    red "apt,apt-get命令均不存在"
    red "仅支持Debian基系统"
    red "不支持的系统"
    exit 1
fi
if [[ -z "${BASH_SOURCE[0]}" ]]; then
    red "请以文件的形式运行脚本，或不支持的bash版本"
    exit 1
fi
if [ "$EUID" != "0" ]; then
    red "请用root用户运行此脚本！！"
    exit 1
fi

check_x86-64_psapi()
{
    # https://dl.xanmod.org/check_x86-64_psabi.sh
    # 一个脚本，来自xanmod官网
cat > check_x86-64_psabi.sh << EOF
#!/usr/bin/awk -f

BEGIN {
    while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
    if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
    if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
    if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
    if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
    if (level > 0) { print "CPU supports x86-64-v" level; exit level + 1 }
    exit 1
}    
EOF
    chmod +x check_x86-64_psabi.sh
    ./check_x86-64_psabi.sh
    local level=$?
    if [ $level -le 1 ] || [ $level -gt 5 ]; then
        red "获取x86-64扩展等级失败"
        exit 1
    fi
    x86_64_psabi_version=$((level - 1))
}

get_install_package()
{
    tyblue "===============安装xanmod内核==============="
    tyblue " 请选择你想安装的版本："
    green  "   1.MAIN(推荐)"
    tyblue "   2.RT"
    tyblue "   3.LTS"
    tyblue "   0.不安装"
    echo
    local install_version
    while true
    do
        read -p "您的选择是：" install_version
        if [[ ! "$install_version" =~ ^(0|[1-9][0-9]*)$ ]] || ((install_version>3)); then
            continue
        fi
        if [ $install_version -eq 2 ] && [ $x86_64_psabi_version -eq 1 ]; then
            red "你的CPU架构不支持RT内核，请选择MAIN/LTS"
            sleep 2s
            continue
        fi
        break
    done
    [ $install_version -eq 0 ] && exit 0
    if [ $install_version -eq 3 ]; then
        if [ $x86_64_psabi_version -eq 1 ]; then
            install_package=linux-xanmod-lts-x64v1
        elif [ $x86_64_psabi_version -eq 2 ]; then
            install_package=linux-xanmod-lts-x64v2
        elif [ $x86_64_psabi_version -eq 3 ]; then
            install_package=linux-xanmod-lts-x64v3
        else
            install_package=linux-xanmod-lts-x64v3
        fi
    elif [ $install_version -eq 2 ]; then
        if [ $x86_64_psabi_version -eq 2 ]; then
            install_package=linux-xanmod-rt-x64v2
        else
            install_package=linux-xanmod-rt-x64v3
        fi
    else
        if [ $x86_64_psabi_version -eq 1 ]; then
            install_package=linux-xanmod-x64v1
        elif [ $x86_64_psabi_version -eq 2 ]; then
            install_package=linux-xanmod-x64v2
        elif [ $x86_64_psabi_version -eq 3 ]; then
            install_package=linux-xanmod-x64v3
        else
            install_package=linux-xanmod-x64v4
        fi
    fi
}

check_mem()
{
    if (($(free -m | sed -n 2p | awk '{print $2}')<300)); then
        red    "检测到内存小于300M，更换内核可能无法开机，请谨慎选择"
        yellow "按回车键以继续或ctrl+c中止"
        read -s
        echo
    fi
}

install_xanmod_source()
{
    [[ -f '/etc/apt/sources.list.d/xanmod-release.list' ]] && xanmod_source_preinstalled=1
    mkdir -p /etc/apt/sources.list.d
    if ! curl -L https://dl.xanmod.org/gpg.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg || ! echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list; then
        red "添加源失败！"
        exit 1
    fi
}

restore_source()
{
    if [ $xanmod_source_preinstalled -ne 1 ]; then
        rm '/etc/apt/sources.list.d/xanmod-release.list'
    fi
}

remove_other_kernel()
{
    kernel_packages=($(LANG="C.UTF-8" LANGUAGE="" dpkg --list | awk '{print $2}' | grep -E '^(linux-headers|linux-image|linux-modules)'))
    for temp_package in "${install_packages[@]}"
    do
        flag=0
        for ((i=${#kernel_packages[@]}-1;i>=0;i--))
        do
            if [ "${kernel_packages[$i]}" == "$temp_package" ]; then
                unset 'kernel_packages[$i]'
                flag=1
                break
            fi
        done
        if [ $flag -eq 0 ]; then
            red "错误:软件包 \"$temp_package\" 未发现，可能安装失败？"
            green  "欢迎进行Bug report(https://github.com/kirin10000/xanmod-install/issues)，感谢您的支持"
            red "卸载失败！"
            return 1
        fi
    done
    yellow "卸载过程中如果询问YES/NO，请选择NO！"
    yellow "卸载过程中如果询问YES/NO，请选择NO！"
    yellow "卸载过程中如果询问YES/NO，请选择NO！"
    tyblue "按回车键以继续。。"
    read -s
    if $apt -y --allow-change-held-packages purge "${kernel_packages[@]}"; then
        apt-mark manual "^grub"
        green "卸载完成"
    else
        apt -y -f install
        apt-mark manual "^grub"
        red "卸载失败！"
    fi
}

main()
{
    check_x86-64_psapi
    get_install_package
    check_important_dependence_installed procps
    check_mem
    check_important_dependence_installed curl
    check_important_dependence_installed ca-certificates
    check_important_dependence_installed gpg
    install_xanmod_source
    if ! test_important_dependence_installed initramfs-tools; then
        red "依赖 initramfs-tools 安装失败！"
        restore_source
        exit 1
    fi
    if ! $apt update && ! $apt update; then
        yellow "warning: $apt update failed!"
    fi
    local install_image_list
    local install_modules_list
    local install_headers_list
    local temp_package
    local temp_packages=($(LANG="en_US.UTF-8" LANGUAGE="en_US:en" apt-cache depends "$install_package" | grep -i "Depends:" | awk '{print $2}'))
    for temp_package in "${temp_packages[@]}"
    do
        if [[ "${temp_package}" =~ ^linux-headers-.*xanmod.* ]]; then
            install_headers_list+=("${temp_package}")
            tyblue "info: add package \"${temp_package}\""
        elif [[ "${temp_package}" =~ ^linux-image-.*xanmod.* ]]; then
            install_image_list+=("${temp_package}")
            tyblue "info: add package \"${temp_package}\""
        elif [[ "${temp_package}" =~ ^linux-modules-.*xanmod.* ]]; then
            install_modules_list+=("${temp_package}")
            tyblue "info: add package \"${temp_package}\""
        fi
    done
    if [ ${#install_image_list[@]} -ne 1 ] || [ ${#install_modules_list[@]} -gt 1 ] || [ ${#install_headers_list[@]} -ne 1 ]; then
        red "获取需安装软件包名失败"
        restore_source
        exit 1
    fi
    install_packages=("${install_image_list[@]}" "${install_modules_list[@]}" "${install_headers_list[@]}")
    if ! $apt_no_install_recommends -y install "${install_packages[@]}"; then
        $apt -y -f install
        if ! $apt_no_install_recommends -y install "${install_packages[@]}"; then
            red "内核安装失败！"
            restore_source
            exit 1
        fi
    fi
    ask_if "是否删除其他内核？(y/n)" && remove_other_kernel
    restore_source
    green "安装完成"
    yellow "系统需要重启"
    if ask_if "现在重启系统? (y/n)"; then
        reboot
    else
        yellow "请尽快重启！"
    fi
}

main
