# 共键双拼输入

> Trime 18 键共键双拼输入方案与主题
> 主题设计参考手心输入法, 实现参考 tongwenfeng
> 输入方案基于 moqi-xh 修改

## 特性

- 仿手心输入法 18 键布局
- 使用模糊音实现共键输入
- 左右滑动精确输入
- 支持双拼辅助码（2 码音/3 码音+形/4 码音+形）
- For Trime
- **当前 repo 中的方案与主题强相关，大部分情况下只能一起使用**

## 布局预览

| 中文 | 英文 |
|:---:|:---:|
| ![中文键盘](assets/cn.jpg) | ![英文键盘](assets/en.jpg) |

| 数字 | 符号 | 编辑 |
|:---:|:---:|:---:|
| ![数字键盘](assets/number.jpg) | ![符号键盘](assets/symbol.jpg) | ![编辑键盘](assets/edit.jpg) |

## 安装

### 前置要求

- Trime v3.3.8+
- 自动化部署：Windows、Windows PowerShell 5.1+，以及已加入 `PATH` 的 ADB
- 手机开启 USB 调试并授权电脑；运行脚本时只连接一台目标设备
- 手动复制文件不需要 ADB 或 PowerShell

### 安装步骤

#### 1. 下载所有文件

**墨奇方案**（必需）

```bash
git clone https://github.com/gaboolic/rime-shuangpin-fuzhuma
```

**本项目**

```bash
git clone https://github.com/hxlh50k/trime-sharedkey-shuangpin
```

#### 2. 准备文件结构

将两个 repo 中内容合并到一个文件夹，先放入墨奇方案，再用本项目文件覆盖同名文件。保留 `Tools` 和 `lua` 的目录结构，`Tools/init_deploy_android.bat` 与 `Tools/init_installation.ps1` 必须放在一起。

#### 3. 部署到手机

**使用自动化脚本**（推荐）

**运行前必须检查并修改 [Tools/init_deploy_android.bat](Tools/init_deploy_android.bat) 顶部的两个目录变量：**

```bat
set "RIME_DIR=/sdcard/rime"
set "SYNC_DIR=/sdcard/com.hxlh/Rime"
```

- `RIME_DIR`：手机上 Trime 实际使用的用户配置目录。默认 `/sdcard/rime`，请与 Trime 设置保持一致；脚本当前要求此路径仅包含英文字母、数字、`_`、`.`、`-` 和 `/`。
- `SYNC_DIR`：手机上的 Rime 同步目录。`/sdcard/com.hxlh/Rime` 是作者的个人设置，**不要直接照搬**；可改为 `/sdcard/rime/sync`，或你自己的同步软件使用的、Trime 可读写的目录。
- 两个变量都填写 **Android 端绝对路径**，不是电脑下载目录。Windows 小狼毫的同步路径需单独设置，不能使用 Android 路径。
- 初始化脚本会覆盖同名配置，并将 `SYNC_DIR` 写入安装信息、覆盖旧同步路径；不会迁移旧目录数据，也不会替你配置跨设备同步。已有同步数据请先备份。

先在手机设置中确认设备/蓝牙名称；此名称会写入 `name` 和 `installation_id`，用于区分同步设备。脚本优先读取自定义蓝牙名称，过滤与产品型号、市场名称相同的值；如果只有默认型号可读，会停止部署。不同设备请使用不同名称，改名不会自动迁移旧的设备同步子目录。

可先在合并后的项目根目录只读预览；下面的路径应替换为你刚设置的值：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tools\init_installation.ps1 -Platform Android -RimeDir "/sdcard/rime" -SyncDir "/sdcard/rime/sync" -WhatIf
```

确认输出的设备名称及来源正确后执行部署：

```powershell
.\Tools\init_deploy_android.bat
```

脚本会创建或补齐手机配置目录中的 `installation.yaml`，包含发行版信息、安装时间、`name`、`installation_id` 和 `sync_dir`；保留已有非空版本与安装时间。缺失版本使用 Trime `v3.3.8-0-gf3f5c923` / librime `1.15.0` 的补缺默认值，不是自动探测结果；可通过辅助脚本的 `-DistributionVersion` / `-RimeVersion` 参数指定。

没有 ADB 时，可按 BAT 的文件清单手动复制到 Trime 用户目录，再在 Trime 中部署。手动方式不会运行安装信息初始化；如需同步，请另外检查设备自身的 `installation.yaml` 中的 `name`、`installation_id` 和 `sync_dir`，不要复制别人的安装文件。

#### 4. 启用方案

1. 打开 Trime → 部署
2. 方案选单 → 启用"MQ+XH 18 键"
3. 键盘设置 → 选择"手心式 18 键"

## 文件说明

**方案配置**:

- `moqi_xh-18key.schema.yaml` - 18 键方案
- `shouxin_18key.trime.yaml` - 18 键键盘布局

**Lua 脚本**:

- `lua/sharedkey_shuangpin_precise_input_processor.lua` - 精确输入处理器
- `lua/sharedkey_shuangpin_precise_input_filter.lua` - 精确输入过滤器
- `lua/sharedkey_shuangpin_auxcode_processor.lua` - 辅助码处理器
- `lua/sharedkey_shuangpin_auxcode_filter.lua` - 辅助码过滤器

**部署脚本**:

- `Tools/init_deploy_android.bat` - 完整部署
- `Tools/init_installation.ps1` - 安装信息初始化，由 BAT 调用，支持 `-WhatIf` 只读预览

### 依赖项（需单独下载）

**墨奇码** (github.com/gaboolic/rime-shuangpin-fuzhuma)

- `moqi.yaml` - 核心配置
- `moqi.extended.dict.yaml` - 主词典
- `moqi_big.extended.dict.yaml` - 大字集
- `moqi_big.schema.yaml` - 大字集方案
- `reverse_moqima.dict.yaml` - 反查
- `cn_dicts_moqi/*` - 词库目录
- `opencc/moqi_chaifen*` - 拆分配置

**sbxlm** (github.com/sbsrf/sbxlm)

- `lua/sbxlm/lib.lua` - Lua 工具库

**可选组件**（推荐）

- Emoji、英文、日语输入方案和词典
- 通用 Lua 脚本（日期、农历、计算器等）
- 其他 OpenCC 配置

## 使用说明

### 基本输入

```
纯音: ui → 时、是、事...
三码: uio → 时 ui[o → 时
四码: ui[oc → 时
```

### 精确输入（消除共键模糊）

**共键对**: WE、RT、IO、SD、FG、JK、XC、BN

**操作方式**:

- **点击 WE 键** → w（模糊匹配，可能是 w 或 e）
- **左滑 WE 键** → W（精确匹配 w）
- **右滑 WE 键** → E（精确匹配 e）

Known issue: 中文模式下长按 Popup 输入大写字母也能精确输入, 但是输入小写字母还是会模糊解析

**示例**:

```
点击WE + 点击IO → wo/wi/eo/ei（模糊）
左滑WE + 点击IO → wo/wi（W精确，O模糊）
左滑WE + 右滑IO → wo（完全精确）
```

### 形码引导键

左下角 `㇕'` 键：

- **点击** → `[`（形码引导符）
- **上滑** → `'`（分词符）

### 快捷输入（来自 moqi）

- `ae` + 字母 → Emoji
- `aw` + 字母 → 英文单词
- `aj` + 字母 → 日语

### 多功能键

- 单击切换 中/EN
- 长按切换系统输入法
- 右滑切换配色
- 上滑切换方案

## 参考与致谢

### 主题设计与配置

- [gaboolic](https://github.com/gaboolic) - 墨奇音形
- Rime 社区
- [手心输入法](https://www.xinshuru.com)
