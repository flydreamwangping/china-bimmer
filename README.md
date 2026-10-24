# Bimmer

macOS 菜单栏 App，对接宝马中国区互联驾驶（myprofile.bmw.com.cn），替代手机上的「Bimmer 控制器」，用于查看车辆状态与远程控制。

- 车况读取 + 远程控制（锁车 / 解锁 / 空调 / 喇叭 / 灯光 / 充电 / 寻车）
- 短信验证码登录（App 内置交互窗口，滑块自动解）
- 逆地理编码显示车辆位置，点击跳转 Apple 地图
- 本地月度里程 / 充电趋势统计
- 开机自动启动（LaunchAgent）

## 使用

安装与使用说明见 [使用文档.md](docs/使用文档.md)。

## 构建

```bash
# 本地运行
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pip install -e .          # 以可编辑方式安装 bimmer 包(src 布局)
python -m bimmer

# 打包成 .app + .dmg（x86_64 机器）
pyinstaller --clean --noconfirm packaging/Bimmer.spec

# Apple Silicon 机器构建 arm64 原生包
./packaging/build_arm64.sh
```

## 说明

- 登录凭据（`config.json` 里的百度地图 AK、`tokens.json` 里的 BMW token）**不会**提交到仓库，需在目标机自行准备。
- 远程指令会真实作用于车辆，请谨慎使用。
