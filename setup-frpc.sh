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
VERSION="1.0.0"

# 默认配置
DEFAULT_IMAGE="fatedier/frpc:v0.61.1"
CONFIG_DIR="/opt/frpc"
PENDING_FILE="$CONFIG_DIR/.pending_setup"

# 显示帮助信息
show_help() {
    cat << EOF
FRP 客户端 Docker 部署脚本 v${VERSION}

使用方法:
    ./setup-frpc.sh [选项] [容器名字]

选项:
    -h, --help          显示帮助信息
    -v, --version       显示版本信息
    -c, --config        仅创建配置文件，不启动容器
    -f, --force         强制重新创建配置文件（覆盖已有配置）
    -i, --image IMAGE   指定 FRP 镜像（默认: ${DEFAULT_IMAGE}）

示例:
    ./setup-frpc.sh                     # 交互式输入容器名字
    ./setup-frpc.sh my_frpc             # 指定容器名字为 my_frpc
    ./setup-frpc.sh -c my_frpc          # 仅创建配置文件
    ./setup-frpc.sh -f my_frpc          # 强制覆盖配置文件
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

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_exit "Docker 未安装，请先安装 Docker"
    fi

    if ! docker info &> /dev/null; then
        error_exit "Docker 服务未运行或无权限访问，请检查 Docker 状态"
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

# 检测配置文件格式
# 返回: ini | toml | unknown
detect_config_format() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        echo "unknown"
        return
    fi

    # INI 格式特征: 检测是否有 [section] 结构
    if grep -qE '^\[[a-zA-Z0-9_-]+\]' "$config_file"; then
        # 进一步检查是否同时有 section 和 key=value 格式
        if grep -qE '^[a-zA-Z0-9_.-]+\s*=\s*[^=\[]' "$config_file"; then
            echo "ini"
            return
        fi
    fi

    # TOML 格式特征: 检测典型的 TOML 语法
    # key = "value" 或 key = 123
    if grep -qE '^[a-zA-Z0-9_.-]+\s*=\s*"[^"]*"' "$config_file" || \
       grep -qE '^\[\[?[a-zA-Z0-9_.-]+\]?\]' "$config_file"; then
        echo "toml"
        return
    fi

    echo "unknown"
}

# 将 INI 格式转换为 TOML 格式
# FRP INI 配置结构映射到 TOML
convert_ini_to_toml() {
    local ini_file="$1"
    local toml_file="$2"

    awk '
    BEGIN {
        current_section = ""
        in_proxies = 0
    }

    # 跳过注释和空行
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }

    # 检测 section
    /^\[/ {
        match($0, /\[([^\]]+)\]/, sections)
        section_name = sections[1]

        # FRP INI 中的常见 section 映射
        if (section_name == "common") {
            current_section = ""
            in_proxies = 0
        } else {
            # 代理配置 section
            current_section = section_name
            in_proxies = 1
            print ""
            print "[[proxies]]"
            print "name = \"" section_name "\""
        }
        next
    }

    # 处理键值对
    /^[^=]+=/ {
        # 移除行首空白
        gsub(/^[[:space:]]+/, "")

        # 分割键和值
        split($0, kv, "=")
        key = kv[1]
        value = kv[2]

        # 清理键名中的空白
        gsub(/[[:space:]]+$/, "", key)

        # 清理值中的空白
        gsub(/^[[:space:]]+/, "", value)

        # 将 INI 的蛇形命名转换为 TOML 的驼峰命名
        if (key == "server_addr") key = "serverAddr"
        else if (key == "server_port") key = "serverPort"
        else if (key == "login_fail_exit") key = "loginFailExit"
        else if (key == "local_ip") key = "localIP"
        else if (key == "local_port") key = "localPort"
        else if (key == "remote_port") key = "remotePort"
        else if (key == "use_encryption") key = "transport.useEncryption"
        else if (key == "use_compression") key = "transport.useCompression"
        else if (key == "host_header_rewrite") key = "header.hostHeaderRewrite"

        # 判断值类型
        if (value ~ /^".*"$/) {
            # 字符串（带引号）
            print key " = " value
        } else if (value ~ /^[0-9]+$/) {
            # 数字
            print key " = " value
        } else if (value ~ /^(true|false)$/) {
            # 布尔值
            print key " = " value
        } else if (value ~ /^[0-9]+\.[0-9]+$/) {
            # 浮点数
            print key " = " value
        } else {
            # 其他情况，作为字符串处理，添加引号
            print key " = \"" value "\""
        }
    }
    ' "$ini_file" > "$toml_file"

    return 0
}

# 处理配置文件（检测格式并转换）
# 返回最终使用的配置文件路径
process_config_file() {
    local container_name="$1"
    local user_config_file="$2"

    local config_format
    config_format=$(detect_config_format "$user_config_file")

    info "检测到配置文件格式: $config_format" >&2

    case "$config_format" in
        "toml")
            # TOML 格式，直接使用
            echo "$user_config_file"
            return
            ;;
        "ini")
            # INI 格式，需要转换
            local converted_file="${user_config_file%.*}.toml"

            info "检测到 INI 格式配置，正在转换为 TOML..."

            # 转换配置
            if convert_ini_to_toml "$user_config_file" "$converted_file"; then
                chmod 600 "$converted_file"
                success "配置转换成功: $converted_file"

                # 保留原始 INI 文件
                mv "$user_config_file" "${user_config_file}.original"
                info "原始 INI 配置已备份到: ${user_config_file}.original"

                echo "$converted_file"
                return
            else
                error_exit "配置转换失败，请检查配置文件格式"
            fi
            ;;
        "unknown")
            warning "无法识别配置文件格式"
            warning "将尝试直接使用该配置文件"
            echo "$user_config_file"
            return
            ;;
    esac
}

# 检查配置文件是否包含未修改的占位符
check_config_placeholders() {
    local config_file="$1"
    local config_format
    config_format=$(detect_config_format "$config_file")

    local has_placeholder=false
    local placeholders=""

    if [ "$config_format" = "toml" ]; then
        # TOML 格式占位符检查
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
    elif [ "$config_format" = "ini" ]; then
        # INI 格式占位符检查
        if grep -q "your-server-address" "$config_file"; then
            has_placeholder=true
            placeholders="${placeholders}\n  - server_addr (服务器地址)"
        fi
        if grep -q "your-user-token" "$config_file"; then
            has_placeholder=true
            placeholders="${placeholders}\n  - token (认证令牌)"
        fi
        if grep -q "my_proxy" "$config_file"; then
            has_placeholder=true
            placeholders="${placeholders}\n  - [my_proxy] (代理名称)"
        fi
    else
        # 未知格式，检查常见占位符
        if grep -q "your-server-address\|your-server-address.com" "$config_file"; then
            has_placeholder=true
            placeholders="${placeholders}\n  - 服务器地址"
        fi
        if grep -q "your-user-token" "$config_file"; then
            has_placeholder=true
            placeholders="${placeholders}\n  - 认证令牌"
        fi
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

    # 询问用户配置格式
    echo ""
    info "请选择配置文件格式:"
    echo "  1) TOML 格式（推荐，frpc v0.52.0+ 默认格式）"
    echo "  2) INI 格式（旧版本格式，会自动转换为 TOML）"
    read -p "请输入选项 [1-2，默认: 1]: " format_choice
    format_choice=${format_choice:-1}

    if [ "$format_choice" = "2" ]; then
        # 生成 INI 格式模板
        cat > "$config_file" << 'EOF'
# ==================== FRP 客户端配置 (INI格式) ====================
# 请根据你的 FRP 服务器信息修改以下配置

[common]
# FRP 服务器地址
server_addr = your-server-address.com

# FRP 服务器端口
server_port = 7000

# 用户认证令牌（从 FRP 服务商获取）
token = your-user-token

# 登录失败时不退出（保持重连）
login_fail_exit = false

# ==================== 代理配置 ====================
# 以下是一个 TCP 代理示例，用于转发本地 Minecraft 服务器

[my_proxy]
# 代理类型: tcp, udp, http, https, stcp, sudp, xtcp
type = tcp

# 本地服务 IP（如果是本机服务，保持 127.0.0.1）
local_ip = 127.0.0.1

# 本地服务端口（例如 Minecraft 默认 25565）
local_port = 25565

# 远程端口（FRP 服务器上的端口，访问地址: server_addr:remote_port）
remote_port = 9000

# 启用加密（推荐）
use_encryption = true

# 启用压缩（推荐）
use_compression = true

# ======================================================
# 如需添加更多代理，复制上面的 [proxy_name] 部分并修改
EOF
        info "已创建 INI 格式配置文件，将在启动容器时自动转换为 TOML"
    else
        # 生成 TOML 格式模板（保持原有逻辑）
        cat > "$config_file" << 'EOF'
# ==================== FRP 客户端配置 ====================
# 请根据你的 FRP 服务器信息修改以下配置

# FRP 服务器地址
serverAddr = "your-server-address.com"

# FRP 服务器端口
serverPort = 7000

# 用户认证令牌（从 FRP 服务商获取）
user = "your-user-token"

# 登录失败时不退出（保持重连）
loginFailExit = false

# ==================== 代理配置 ====================
# 以下是一个 TCP 代理示例，用于转发本地 Minecraft 服务器

[[proxies]]
# 代理类型: tcp, udp, http, https, stcp, sudp, xtcp
type = "tcp"

# 代理名称（每个代理必须唯一）
name = "your-proxy-name"

# 本地服务 IP（如果是本机服务，保持 127.0.0.1）
localIP = "127.0.0.1"

# 本地服务端口（例如 Minecraft 默认 25565）
localPort = 25565

# 远程端口（FRP 服务器上的端口，访问地址: serverAddr:remotePort）
remotePort = 9000

# 启用加密（推荐）
transport.useEncryption = true

# 启用压缩（推荐）
transport.useCompression = true

# ======================================================
# 如需添加更多代理，复制上面的 [[proxies]] 部分并修改
EOF
    fi

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
    local image="$DEFAULT_IMAGE"

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
                    read -p "是否继续配置该容器? [Y/n]: " continue_choice
                    continue_choice=${continue_choice:-Y}
                    if [[ "$continue_choice" =~ ^[Yy] ]]; then
                        container_name="$pending_name"
                        info "自动使用容器名字: $container_name"
                    else
                        read -p "请输入容器名字: " container_name
                    fi
                else
                    # 配置文件不存在，删除 pending 文件
                    rm -f "$PENDING_FILE"
                    read -p "请输入容器名字: " container_name
                fi
            else
                read -p "请输入容器名字: " container_name
            fi
        else
            read -p "请输入容器名字: " container_name
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
        read -p "请重新输入容器名字: " container_name
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

    # 处理配置文件（检测格式并转换）
    final_config_file=$(process_config_file "$container_name" "$config_file")
    success "使用配置文件: $final_config_file"

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
        -v "$final_config_file:/etc/frp/frpc.toml:ro" \
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
