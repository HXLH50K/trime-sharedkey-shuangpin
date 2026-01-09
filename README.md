# 共键双拼输入

> 基于moqi-xh的Android 18键共键双拼输入方案与主题

## 特性

- 仿手心输入法18键布局
- 使用模糊音实现共键输入
- 左右滑动精确输入
- 支持双拼辅助码（2码音/3码音+形/4码音+形）
- For Trime
- **当前repo中的方案与主题强相关，大部分情况下只能一起使用**

## 安装

### 前置要求

- Trime v3.3.8+
- ADB (可选)

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

将两个repo中内容合并到一个文件夹

#### 3. 部署到手机

**使用自动化脚本**（推荐）

```bash
cd Tools

# 执行部署
init_deploy_android.bat
```

如果你没有adb，参考此bat中的文件手动复制，或者全复制进去也行。

#### 4. 启用方案

1. 打开Trime → 部署
2. 方案选单 → 启用"MQ+XH 18键"
3. 键盘设置 → 选择"手心式18键"

## 文件说明

**方案配置**:
- `moqi_xh-18key.schema.yaml` - 18键方案
- `shouxin_18key.trime.yaml` - 18键键盘布局

**Lua脚本**:
- `lua/sharedkey_shuangpin_precise_input_processor.lua` - 精确输入处理器
- `lua/sharedkey_shuangpin_precise_input_filter.lua` - 精确输入过滤器

**部署脚本**:
- `Tools/init_deploy_android.bat` - 完整部署
- `Tools/deploy_android.bat` - 快速更新

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
- `lua/sbxlm/lib.lua` - Lua工具库

**可选组件**（推荐）
- Emoji、英文、日语输入方案和词典
- 通用Lua脚本（日期、农历、计算器等）
- 其他OpenCC配置

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
- **点击WE键** → w（模糊匹配，可能是w或e）
- **左滑WE键** → W（精确匹配w）
- **右滑WE键** → E（精确匹配e）

**示例**:
```
点击WE + 点击IO → wo/wi/eo/ei（模糊）
左滑WE + 点击IO → wo/wi（W精确，O模糊）
左滑WE + 右滑IO → wo（完全精确）
```

### 形码引导键

左下角 `㇕'` 键：
- **点击** → `[`（进入形码输入）
- **上滑** → `'`（分词符）

### 快捷输入（来自moqi）

- `ae` + 字母 → Emoji
- `aw` + 字母 → 英文单词
- `aj` + 字母 → 日语

### 多功能键
- 单击切换 中/EN
- 长按切换系统输入法
- 右滑切换配色
- 上滑切换方案

## 
- [gaboolic](https://github.com/gaboolic) - 墨奇音形
- Rime社区
- [手心输入法](https://www.xinshuru.com)