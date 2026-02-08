# FRPC Docker Deploy

一个简单易用的 FRP 客户端 Docker 一键部署脚本。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/kevin25858/frpc-docker-deploy)

## 功能特性

- 🚀 一键部署 FRP 客户端容器
- 📝 自动生成配置文件模板
- 🎨 彩色输出，友好的交互体验
- 🔧 支持自定义容器名称和镜像版本
- 🛡️ 完整的错误处理和参数校验
- 📖 详细的配置注释说明

## 快速开始

### 1. 下载脚本

#### 方式一：GitHub 官方（国际网络）
```bash
curl -fsSL https://raw.githubusercontent.com/kevin25858/frpc-docker-deploy/main/setup-frpc.sh -o setup-frpc.sh
chmod +x setup-frpc.sh
```

#### 方式二：Gitee（国内访问更快）
```bash
curl -fsSL https://gitee.com/kevin25858/frpc-docker-deploy/raw/main/setup-frpc.sh -o setup-frpc.sh
chmod +x setup-frpc.sh
```

#### 方式三：直接下载 .sh 文件
```bash
# 使用 wget 下载（适合没有 curl 的系统）
wget https://gitee.com/kevin25858/frpc-docker-deploy/raw/main/setup-frpc.sh -O setup-frpc.sh
chmod +x setup-frpc.sh
```

#### 方式四：手动下载
如果以上方式都慢，可以直接复制 [setup-frpc.sh](setup-frpc.sh) 内容保存到本地。

### 2. 运行脚本

下载并自动运行（推荐）：
```bash
# 国内镜像 - 下载后自动运行
curl -fsSL https://fastly.jsdelivr.net/gh/kevin25858/frpc-docker-deploy@main/setup-frpc.sh | bash

# GitHub 官方 - 下载后自动运行
curl -fsSL https://raw.githubusercontent.com/kevin25858/frpc-docker-deploy/main/setup-frpc.sh | bash
```

或者先下载再运行：
```bash
# 下载脚本
curl -fsSL https://fastly.jsdelivr.net/gh/kevin25858/frpc-docker-deploy@main/setup-frpc.sh -o setup-frpc.sh
chmod +x setup-frpc.sh

# 运行脚本（会交互式询问容器名字）
./setup-frpc.sh
```

### 3. 编辑配置文件

```bash
nano /opt/frpc/my_frpc.toml
```

根据实际情况修改：
- `serverAddr` - FRP 服务器地址
- `serverPort` - FRP 服务器端口
- `user` - 用户认证令牌
- `proxies` 部分的代理配置

### 4. 重启容器生效

```bash
docker restart my_frpc
```

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
| `-f, --force` | 强制重新创建配置文件（覆盖已有配置） |
| `-i, --image IMAGE` | 指定 FRP 镜像（默认: fatedier/frpc:v0.61.1） |

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

# 停止容器
docker stop <容器名字>

# 启动容器
docker start <容器名字>

# 重启容器
docker restart <容器名字>

# 删除容器
docker rm -f <容器名字>
```

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
- [Docker Hub - fatedier/frpc]