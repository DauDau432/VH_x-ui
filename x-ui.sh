#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "  lỗi: Tập lệnh này phải được chạy với quyền root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "  Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả kịch bản！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "  Vui lòng sử dụng CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "  Vui lòng sử dụng Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "  Vui lòng sử dụng Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [mặc định $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "  Có khởi động lại bảng điều khiển hay không, việc khởi động lại bảng điều khiển cũng sẽ khởi động lại xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "  Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/DauDau432/VH_x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "  Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất hiện tại và dữ liệu sẽ không bị mất. Bạn có muốn tiếp tục không?" "n"
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "  Đã hủy${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/DauDau432/VH_x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "  Cập nhật hoàn tất và bảng điều khiển đã được tự động khởi động lại${plain}"
        exit 0
    fi
}

uninstall() {
    confirm "  Bạn có chắc chắn muốn gỡ cài đặt bảng điều khiển không, xray cũng sẽ gỡ cài đặt?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "  Quá trình gỡ cài đặt thành công."
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "  Bạn có chắc chắn muốn đặt lại tên người dùng và mật khẩu cho quản trị viên không" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo ""
    echo -e "  Tên người dùng và mật khẩu đã được đặt lại thành ${green}admin${plain}，Bây giờ hãy khởi động lại bảng điều khiển"
    confirm_restart
}

reset_config() {
    confirm "  Bạn có chắc chắn muốn đặt lại tất cả cài đặt bảng điều khiển không? Dữ liệu tài khoản sẽ không bị mất, tên người dùng và mật khẩu sẽ không bị thay đổi" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "  Tất cả cài đặt bảng điều khiển đã được đặt lại về giá trị mặc định, vui lòng khởi động lại bảng điều khiển và sử dụng giá trị mặc định ${green}54321${plain} Bảng điều khiển truy cập cổng"
    confirm_restart
}

set_port() {
    echo && echo -n -e "  Nhập số cổng[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "  Đã hủy${plain}"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "  Sau khi thiết lập cổng, vui lòng khởi động lại bảng điều khiển và sử dụng cổng mới đặt ${green}${port}${plain} Bảng điều khiển truy cập"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo -e "  Bảng đã chạy rồi, không cần khởi động lại, nếu cần khởi động lại, vui lòng chọn khởi động lại${plain}"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo ""
            echo -e "  x-ui Đã chạy thành công${plain}"
        else
            echo -e "  Bảng điều khiển không khởi động được. Có thể do thời gian khởi động vượt quá hai giây. Vui lòng kiểm tra thông tin nhật ký.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "  Bảng điều khiển đã dừng, không cần dừng lại${plain}"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo ""
            echo -e "  x-ui và xray đã dừng thành công${plain}"
        else
            echo -e "  Bảng điều khiển không dừng được. Có thể do thời gian dừng vượt quá hai giây. Vui lòng kiểm tra thông tin nhật ký.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "  x-ui và xray khởi động lại thành công${plain}"
    else
        echo -e "  Khởi động lại bảng điều khiển không thành công, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "  x-ui bật tự động khởi động thành công ${plain}"
    else
        echo -e "  x-ui Không thể bật tự động khởi động"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        echo -e "  x-ui Hủy tự động khởi động thành công${plain}"
    else
        echo -e "  x-ui Hủy tự động khởi động thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/DauDau432/Linux-NetSpeed/master/tcp.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://raw.githubusercontent.com/DauDau432/VH_x-ui/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "  Không tải được script xuống, vui lòng kiểm tra xem máy có thể kết nối với Github không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        echo -e "  Tập lệnh nâng cấp thành công, vui lòng chạy lại tập lệnh${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "  Bảng điều khiển đã được cài đặt, vui lòng không cài đặt nhiều lần${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "  Vui lòng cài đặt bảng điều khiển trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "  Trạng thái bảng điều khiển: Đã chạy"
            show_enable_status
            ;;
        1)
            echo -e "  Trạng thái bảng điều khiển: Không chạy"
            show_enable_status
            ;;
        2)
            echo -e "  Trạng thái bảng điều khiển: Chưa được cài đặt"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "  Có tự động khởi động không: Có"
    else
        echo -e "  Có tự động khởi động không: không"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "  trạng thái xray: Đã chạy"
    else
        echo -e "  trạng thái xray: Không chạy"
    fi
}
 
show_usage() {
    echo ""
    echo -e "  ${green}[Đậu Đậu việt hóa] "
    echo -e "  ${plain}Cách sử dụng tập lệnh quản lý x-ui       "
    echo -e "------------------------------------------"
    echo -e "  x-ui              - Hiển thị menu quản lý (nhiều chức năng hơn)"
    echo -e "  x-ui start        - Khởi chạy bảng điều khiển x-ui"
    echo -e "  x-ui stop         - Dừng bảng điều khiển x-ui"
    echo -e "  x-ui restart      - Khởi động lại bảng điều khiển x-ui"
    echo -e "  x-ui status       - Xem trạng thái x-ui"
    echo -e "  x-ui enable       - Đặt tự động khởi động x-ui"
    echo -e "  x-ui disable      - Hủy tự động khởi động x-ui"
    echo -e "  x-ui log          - Xem nhật ký x-ui"
    echo -e "  x-ui v2-ui        - Di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo -e "  x-ui update       - Cập nhật bảng điều khiển x-ui"
    echo -e "  x-ui install      - Cài đặt bảng điều khiển x-ui"
    echo -e "  x-ui uninstall    - Gỡ cài đặt bảng điều khiển x-ui"
    echo -e "------------------------------------------"
}

show_menu() {
  echo ""
  echo -e "     
${green}-------[Đậu Đậu việt hóa]-------${plain}
   x-ui.${plain} Tập lệnh quản lý bảng điều khiển
   0.${plain} Thoát
————————————————————————————————
   1.${plain} Cài đặt x-ui
   2.${plain} Cập nhật x-ui
   3.${plain} Gỡ cài đặt x-ui
————————————————————————————————
   4.${plain} Đặt lại tên người dùng và mật khẩu
   5.${plain} Đặt lại cài đặt bảng điều khiển
   6.${plain} Đặt cổng bảng điều khiển
————————————————————————————————
   7.${plain} Khởi động x-ui
   8.${plain} Dừng lại x-ui
   9.${plain} Khởi động lại x-ui
  10.${plain} Xem trạng thái x-ui
  11.${plain} Xem nhật ký x-ui
————————————————————————————————
  12.${plain} Đặt tự động khởi động x-ui 
  13.${plain} Hủy tự động khởi động x-ui 
  14.${plain} Cài đặt bbr (hạt nhân mới nhất)
————————————————————————————————  
 "
    show_status
    echo && read -p "  Vui lòng nhập lựa chọn [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "  Vui lòng nhập số chính xác [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
