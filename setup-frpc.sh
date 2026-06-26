#!/bin/bash

# FRP 客户端一键部署脚本
# 项目地址: https://github.com/kevin25858/frpc-docker-deploy
# 开源协议: MIT License
# 使用方法: ./setup-frpc.sh [容器名字]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本信息
VERSION="2.0.0"

# 默认配置
FALLBACK_VERSION="v0.61.1"
DEFAULT_IMAGE="fatedier/frpc:${FALLBACK_VERSION}"
CONFIG_DIR="/opt/frpc"
PENDING_FILE="$CONFIG_DIR/.pending_setup"

# 显示帮助信息
show_help() {
    cat << EOF
FRP 客户端 Docker 部署脚本 v${VERSION}

使用方法:
    ./setup-frpc.sh [选项] [容器名字]

选项:
    -h, --help              显示帮助信息
    -v, --version           显示版本信息
    -c, --config            仅创建配置文件，不启动容器
    -f, --force             强制重新创建配置文件（覆盖已有配置）
    -r, --release VERSION   指定 frp 版本（默认: 自动获取最新版）
    -i, --image IMAGE       指定完整镜像名称（覆盖 -r）

示例:
    ./setup-frpc.sh                     # 交互式输入容器名字
    ./setup-frpc.sh my_frpc             # 指定容器名字为 my_frpc
    ./setup-frpc.sh -c my_frpc          # 仅创建配置文件
    ./setup-frpc.sh -f my_frpc          # 强制覆盖配置文件
    ./setup-frpc.sh -r v0.61.1 my_frpc  # 指定 frp 版本
    ./setup-frpc.sh -i fatedier/frpc:latest my_frpc

配置文件位置: ${CONFIG_DIR}/<容器名字>.toml
EOF
}

# 显示版本信息
show_version() {
    echo "FRP 客户端 Docker 部署脚本 v${VERSION}"
}

# 错误处理
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

# 信息输出
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 成功输出
success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# 警告输出
warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 获取 frp 最新 release 版本号
get_latest_release() {
    local latest
    latest=$(curl -fsSL --connect-timeout 5 --max-time 10 \
        "https://api.github.com/repos/fatedier/frp/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/v\1/')
    if [ -n "$latest" ]; then
        echo "$latest"
    else
        echo ""
    fi
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_exit "Docker 未安装，请先安装 Docker"
    fi

    if ! docker info &> /dev/null; then
        if groups 2>/dev/null | grep -q '\bdocker\b'; then
            error_exit "Docker 服务未运行，请使用 systemctl start docker 启动"
        else
            error_exit "当前用户无权限操作 Docker，请使用 sudo 运行或将当前用户添加到 docker 组: sudo usermod -aG docker \$USER"
        fi
    fi
}

# 备份配置文件
backup_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        chmod 600 "$backup_file"
        info "已备份原配置到: $backup_file"
    fi
}

# 检查配置文件是否包含未修改的占位符
check_config_placeholders() {
    local config_file="$1"

    local has_placeholder=false
    local placeholders=""

    if grep -q "your-server-address" "$config_file"; then
        has_placeholder=true
        placeholders="${placeholders}\n  - serverAddr (服务器地址)"
    fi
    if grep -q "your-user-token" "$config_file"; then
        has_placeholder=true
        placeholders="${placeholders}\n  - user (认证令牌)"
    fi
    if grep -q "your-proxy-name" "$config_file"; then
        has_placeholder=true
        placeholders="${placeholders}\n  - proxies.name (代理名称)"
    fi

    if [ "$has_placeholder" = "true" ]; then
        echo ""
        warning "配置文件包含未修改的占位符:"
        echo -e "$placeholders"
        echo ""
        info "请编辑配置文件后重新运行脚本"
        info "编辑命令: nano $config_file"
        return 1
    fi
    return 0
}

# 创建配置文件
create_config() {
    local config_file="$1"
    local force="$2"

    if [ -f "$config_file" ] && [ "$force" != "true" ]; then
        warning "配置文件已存在: $config_file"
        return 0
    fi

    # 备份原配置（如果存在）
    if [ -f "$config_file" ] && [ "$force" = "true" ]; then
        backup_config "$config_file"
    fi

    cat > "$config_file" << 'EOF'
# FRP 客户端配置 - 请修改以下配置项

serverAddr = "your-server-address.com"           # FRP 服务器地址
serverPort = 7000                                # FRP 服务器端口
user = "your-user-token"                         # 用户认证令牌（从服务商获取）
loginFailExit = false                            # 登录失败时不退出

[[proxies]]
type = "tcp"                                     # 代理类型: tcp, udp, http, https
name = "your-proxy-name"                         # 代理名称（每个代理唯一）
localIP = "127.0.0.1"                            # 本地服务 IP
localPort = 25565                                # 本地服务端口
remotePort = 9000                                # 远程端口
transport.useEncryption = true                   # 启用加密
transport.useCompression = true                  # 启用压缩
EOF

    chmod 600 "$config_file"
    success "创建配置文件: $config_file"
    if [ "$force" = "true" ]; then
        info "已强制覆盖原有配置"
    fi
}

# 主函数
main() {
    local container_name=""
    local only_config="false"
    local force="false"
    local image=""
    local release_version=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -c|--config)
                only_config="true"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -r|--release)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    release_version="$2"
                    shift 2
                else
                    error_exit "--release 参数需要指定版本号"
                fi
                ;;
            -i|--image)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    image="$2"
                    shift 2
                else
                    error_exit "--image 参数需要指定镜像名称"
                fi
                ;;
            -*)
                error_exit "未知选项: $1，使用 --help 查看帮助"
                ;;
            *)
                container_name="$1"
                shift
                ;;
        esac
    done

    # 确定镜像：-i 优先，否则用 -r 指定版本，否则获取最新版本
    if [ -z "$image" ]; then
        if [ -n "$release_version" ]; then
            image="fatedier/frpc:${release_version}"
        else
            info "正在获取 frp 最新版本..." >&2
            local latest_version
            latest_version=$(get_latest_release)
            if [ -n "$latest_version" ]; then
                info "检测到最新版本: $latest_version" >&2
                image="fatedier/frpc:${latest_version}"
            else
                warning "获取最新版本失败，使用回退版本: ${FALLBACK_VERSION}" >&2
                image="$DEFAULT_IMAGE"
            fi
        fi
    fi

    # 如果没有指定容器名字，检查是否有未完成的配置
    if [ -z "$container_name" ]; then
        # 检查是否存在未完成的配置
        if [ -f "$PENDING_FILE" ]; then
            local pending_name
            pending_name=$(cat "$PENDING_FILE" 2>/dev/null)
            if [ -n "$pending_name" ]; then
                local pending_config="$CONFIG_DIR/${pending_name}.toml"
                # 检查配置文件是否存在且仍包含占位符
                if [ -f "$pending_config" ]; then
                    info "检测到未完成的配置项目: $pending_name"
                    read -ep "是否继续配置该容器? [Y/n]: " continue_choice
                    continue_choice=${continue_choice:-Y}
                    if [[ "$continue_choice" =~ ^[Yy] ]]; then
                        container_name="$pending_name"
                        info "自动使用容器名字: $container_name"
                    else
                        read -ep "请输入容器名字: " container_name
                    fi
                else
                    # 配置文件不存在，删除 pending 文件
                    rm -f "$PENDING_FILE"
                    read -ep "请输入容器名字: " container_name
                fi
            else
                read -ep "请输入容器名字: " container_name
            fi
        else
            read -ep "请输入容器名字: " container_name
        fi
        
        if [ -z "$container_name" ]; then
            error_exit "容器名字不能为空"
        fi
    fi

    # 验证容器名字（允许字母或数字开头，可包含字母、数字、下划线、横线）
    if [[ ! "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        error_exit "容器名字必须以字母或数字开头，只能包含字母、数字、下划线、横线和圆点"
    fi

    # 检查容器名字是否已存在
    while docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; do
        warning "容器名字 '$container_name' 已被使用"
        read -ep "请重新输入容器名字: " container_name
        if [ -z "$container_name" ]; then
            error_exit "容器名字不能为空"
        fi
        if [[ ! "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
            error_exit "容器名字必须以字母或数字开头，只能包含字母、数字、下划线、横线和圆点"
        fi
    done

    echo ""
    info "开始部署 FRP 客户端"
    info "容器名字: $container_name"
    info "镜像: $image"
    echo ""

    # 检查 Docker
    check_docker
    success "Docker 检查通过"

    # 检查配置目录权限
    if [ -d "$CONFIG_DIR" ]; then
        if [ ! -w "$CONFIG_DIR" ]; then
            error_exit "没有权限写入配置目录 $CONFIG_DIR，请使用 sudo 运行"
        fi
    else
        local parent_dir
        parent_dir=$(dirname "$CONFIG_DIR")
        if [ ! -w "$parent_dir" ]; then
            error_exit "没有权限在 $parent_dir 下创建配置目录，请使用 sudo 运行"
        fi
    fi

    # 创建配置目录和日志目录
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    success "创建配置目录: $CONFIG_DIR"

    # 创建日志目录
    local log_dir="$CONFIG_DIR/logs/$container_name"
    mkdir -p "$log_dir"
    chmod 700 "$log_dir"
    success "创建日志目录: $log_dir"

    # 配置文件路径
    config_file="$CONFIG_DIR/${container_name}.toml"

    # 创建配置文件
    create_config "$config_file" "$force"
    
    # 保存未完成的配置项目
    echo "$container_name" > "$PENDING_FILE"
    chmod 600 "$PENDING_FILE"

    # 如果仅创建配置，到此结束
    if [ "$only_config" = "true" ]; then
        echo ""
        success "配置文件创建完成"
        info "配置文件位置: $config_file"
        info "请编辑配置文件后，再次运行脚本启动容器"
        exit 0
    fi

    # 检查配置文件是否包含占位符
    if ! check_config_placeholders "$config_file"; then
        exit 1
    fi

    success "使用配置文件: $config_file"

    # 拉取镜像
    info "拉取 FRP 客户端镜像: $image"
    if docker pull "$image"; then
        success "镜像拉取完成"
    else
        error_exit "镜像拉取失败，请检查网络连接或镜像名称"
    fi

    # 停止并删除旧容器（如果存在）
    info "检查并清理旧容器..."
    docker stop "$container_name" &> /dev/null || true
    docker rm "$container_name" &> /dev/null || true

    # 启动新容器
    info "启动容器..."
    if docker run -d \
        --name "$container_name" \
        --network host \
        --restart always \
        -v "$config_file:/etc/frp/frpc.toml:ro" \
        -v "$log_dir:/var/log/frp" \
        --health-cmd="pgrep frpc || exit 1" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        "$image" \
        -c /etc/frp/frpc.toml; then
        success "容器启动成功"
        # 清除未完成配置记录
        rm -f "$PENDING_FILE"
    else
        error_exit "容器启动失败"
    fi

    # 等待容器启动完成
    sleep 2
    local container_status
    container_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo 'unknown')
    local health_status
    health_status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo 'N/A')

    # 显示完成信息
    echo ""
    echo "========================================"
    success "FRP 客户端部署完成"
    echo "========================================"
    echo ""
    info "容器信息:"
    echo "  容器名字: $container_name"
    echo "  配置文件: $config_file"
    echo "  日志目录: $log_dir"
    echo "  容器状态: $container_status"
    echo "  健康状态: $health_status"
    echo ""
    info "常用命令:"
    echo "  查看日志: docker logs -f $container_name"
    echo "  查看日志文件: ls $log_dir"
    echo "  停止容器: docker stop $container_name"
    echo "  启动容器: docker start $container_name"
    echo "  重启容器: docker restart $container_name"
    echo "  删除容器: docker rm -f $container_name"
    echo ""
    info "编辑命令: nano $config_file"
    echo ""
}

# 执行主函数
main "$@"
