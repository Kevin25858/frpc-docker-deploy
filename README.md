# FRPC Docker Deploy

一个简单易用的 FRP 客户端 Docker 一键部署脚本。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/kevin25858/frpc-docker-deploy)

## 功能特性

- 一键部署、自动配置
- 容器冲突检测、自动重启
- 配置备份、日志持久化
- 健康检查、自定义镜像
- 自动获取最新 frp 版本，支持指定版本
- 未完成配置自动检测

## 快速开始

### 下载并运行

#### 方式一：GitHub 官方（国际网络）
```bash
curl -fsSL -o ~/setup-frpc.sh https://raw.githubusercontent.com/kevin25858/frpc-docker-deploy/main/setup-frpc.sh && bash ~/setup-frpc.sh
```

#### 方式二：Gitee（国内访问更快）
```bash
curl -fsSL -o ~/setup-frpc.sh https://gitee.com/kevin25858/frpc-docker-deploy/raw/main/setup-frpc.sh && bash ~/setup-frpc.sh
```

#### 方式三：手动下载运行
如果以上方式都慢，可以手动下载 [setup-frpc.sh](setup-frpc.sh) 后执行 `./setup-frpc.sh`

### 编辑配置文件

```bash
nano /opt/frpc/<容器名字>.toml
```

> 💡 **提示**：配置文件可直接从 FRP 服务商处复制粘贴替换，无需逐行编辑

根据实际情况修改：
- `serverAddr` - FRP 服务器地址
- `serverPort` - FRP 服务器端口
- `user` - 用户认证令牌
- `proxies` 部分的代理配置

> ⚠️ **安全提示**：脚本会自动将配置文件权限设为 600（仅所有者可读写），防止敏感信息泄露

### 再次运行脚本启动容器

```bash
./setup-frpc.sh
```

脚本会自动检测到未完成的配置项目，无需再次输入容器名字。

> ✅ **配置检查**：脚本启动前会自动检查配置是否包含未修改的占位符，避免连接失败

## 使用方法

### 基本用法

```bash
./setup-frpc.sh [选项] [容器名字]
```

### 命令选项

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `-v, --version` | 显示版本信息 |
| `-c, --config` | 仅创建配置文件，不启动容器 |
| `-f, --force` | 强制重新创建配置文件（覆盖前自动备份） |
| `-i, --image IMAGE` | 指定完整镜像名称（覆盖 -r） |
| `-r, --release VERSION` | 指定 frp 版本（默认: 自动获取最新版） |

> 💾 **备份机制**：使用 `-f` 强制覆盖时，原配置会自动备份到 `.backup.时间戳` 文件

### 使用示例

```bash
# 交互式输入容器名字
./setup-frpc.sh

# 指定容器名字
./setup-frpc.sh my_frpc

# 仅创建配置文件
./setup-frpc.sh -c my_frpc

# 强制覆盖配置文件
./setup-frpc.sh -f my_frpc

# 指定 frp 版本
./setup-frpc.sh -r v0.61.1 my_frpc

# 使用最新版镜像
./setup-frpc.sh -i fatedier/frpc:latest my_frpc
```

## 配置文件说明

配置文件默认位置：`/opt/frpc/<容器名字>.toml`

### 基本配置项

```toml
# FRP 服务器地址
serverAddr = "your-server-address.com"

# FRP 服务器端口
serverPort = 7000

# 用户认证令牌
user = "your-user-token"

# 登录失败时不退出
loginFailExit = false
```

### 代理配置

```toml
[[proxies]]
type = "tcp"
name = "your-proxy-name"
localIP = "127.0.0.1"
localPort = 25565
remotePort = 9000
transport.useEncryption = true
transport.useCompression = true
```

## 常用命令

```bash
# 查看容器日志
docker logs -f <容器名字>

# 查看持久化日志文件
ls /opt/frpc/logs/<容器名字>/

# 停止容器
docker stop <容器名字>

# 启动容器
docker start <容器名字>

# 重启容器
docker restart <容器名字>

# 删除容器
docker rm -f <容器名字>

# 查看容器健康状态
docker inspect -f '{{.State.Health.Status}}' <容器名字>
```

## 目录结构

```
/opt/frpc/
├── <容器名>.toml           # 配置文件（权限 600）
├── <容器名>.toml.backup.*  # 自动备份的配置文件
├── .pending_setup          # 未完成配置记录
└── logs/
    └── <容器名>/           # 持久化日志目录（权限 700）
        └── frpc.log
```

## 安全特性

- **文件权限控制**：配置目录 700，配置文件 600，防止其他用户读取敏感信息
- **自动备份**：使用 `--force` 覆盖配置前自动备份原文件
- **配置验证**：启动前检查占位符是否已修改，避免无效配置启动
- **容器健康检查**：内置健康检查机制，自动监控 frpc 进程状态

## 系统要求

- Linux 操作系统
- Docker 已安装并运行
- 具有 Docker 操作权限的用户

## 安装 Docker

如果尚未安装 Docker，可以使用以下命令安装：

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh

# CentOS/RHEL
curl -fsSL https://get.docker.com | sh

# 添加用户到 docker 组（免 sudo 使用 docker）
sudo usermod -aG docker $USER
```

## 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关链接

- [FRP 官方文档](https://gofrp.org/)
- [FRP GitHub](https://github.com/fatedier/frp)
- [Docker Hub - fatedier/frpc](https://hub.docker.com/r/fatedier/frpc)
