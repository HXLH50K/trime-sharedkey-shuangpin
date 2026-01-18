@echo off
chcp 65001 >nul
REM ========================================
REM 初次部署 Rime 配置到 Android 设备
REM 基于 moqi_xh-18key.schema.yaml 和 shouxin_18key.trime.yaml 的完整依赖分析
REM 依赖文档: plans/init_deploy_android_dependencies.md
REM ========================================

REM ========================================
REM 配置变量：目标目录
REM 修改此变量可快速切换部署目标（rime, rime1, rime2, rime3...）
REM ========================================
set RIME_DIR=/sdcard/rime

echo ========================================
echo 初次部署 Rime 配置到 Android 设备
echo 目标目录: %RIME_DIR%
echo ========================================
echo.

REM ========================================
REM 阶段1: 检查并准备目录结构（增量部署模式）
REM ========================================
echo [阶段1/5] 检查并准备目录结构...
echo   注意：此脚本采用增量部署模式，不会删除现有内容

REM 检查根目录是否为文件（而非目录），如果是则终止
echo   - 检查目标路径 %RIME_DIR%...
adb shell "if [ -f %RIME_DIR% ]; then echo '错误：%RIME_DIR% 是一个文件而非目录！'; echo '请手动删除该文件后重试。'; exit 1; fi"
if errorlevel 1 (
    echo.
    echo ========================================
    echo 部署终止！
    echo ========================================
    echo 原因: %RIME_DIR% 已存在且是一个文件
    echo 请手动删除该文件后重新运行此脚本
    echo.
    pause
    exit /b 1
)

REM 确保根目录存在
echo   - 创建目标目录 %RIME_DIR%...
adb shell "mkdir -p %RIME_DIR%"

echo [阶段1/5] 完成
echo.

REM ========================================
REM 阶段2: 基础配置文件和词典文件
REM ========================================
echo [阶段2/5] 部署基础配置文件和词典...

REM 2.1 基础配置文件
REM default.yaml 和 default.custom.yaml 由 Trime/Weasel 自动生成，无需手动部署
adb push moqi.yaml %RIME_DIR%
adb push symbols_caps_v.yaml %RIME_DIR%
adb push shouxin_18key.trime.yaml %RIME_DIR%

REM 2.2 词库子目录
echo   - 部署墨奇词库 (cn_dicts_moqi/)...
adb shell mkdir -p %RIME_DIR%/cn_dicts_moqi
adb push cn_dicts_moqi/8105.dict.yaml %RIME_DIR%/cn_dicts_moqi
adb push cn_dicts_moqi/41448.dict.yaml %RIME_DIR%/cn_dicts_moqi
adb push cn_dicts_moqi/base.dict.yaml %RIME_DIR%/cn_dicts_moqi
adb push cn_dicts_moqi/ext.dict.yaml %RIME_DIR%/cn_dicts_moqi
adb push cn_dicts_moqi/cell.dict.yaml %RIME_DIR%/cn_dicts_moqi
REM 可选: adb push cn_dicts_moqi/others.dict.yaml %RIME_DIR%/cn_dicts_moqi

echo   - 部署通用词库 (cn_dicts_common/)...
adb shell mkdir -p %RIME_DIR%/cn_dicts_common
adb push cn_dicts_common/user.dict.yaml %RIME_DIR%/cn_dicts_common
adb push cn_dicts_common/changcijian.dict.yaml %RIME_DIR%/cn_dicts_common
adb push cn_dicts_common/changcijian3.dict.yaml %RIME_DIR%/cn_dicts_common

REM 2.3 主词典文件
echo   - 部署主词典文件...
adb push moqi.extended.dict.yaml %RIME_DIR%
adb push moqi_big.extended.dict.yaml %RIME_DIR%

REM 2.4 依赖词典
echo   - 部署依赖词典...
adb push easy_en.dict.yaml %RIME_DIR%
adb push jp_sela.dict.yaml %RIME_DIR%
adb push emoji.dict.yaml %RIME_DIR%
adb push cangjie5.dict.yaml %RIME_DIR%
adb push radical_flypy.dict.yaml %RIME_DIR%
adb push reverse_moqima.dict.yaml %RIME_DIR%

echo [阶段2/5] 完成
echo.

REM ========================================
REM 阶段3: 输入方案
REM ========================================
echo [阶段3/5] 部署输入方案...
adb push moqi_xh-18key.schema.yaml %RIME_DIR%

REM 3.1 依赖方案 (dependencies)
echo   - 部署依赖方案...
adb push emoji.schema.yaml %RIME_DIR%
adb push easy_en.schema.yaml %RIME_DIR%
adb push jp_sela.schema.yaml %RIME_DIR%
adb push moqi_big.schema.yaml %RIME_DIR%

echo [阶段3/5] 完成
echo.

REM ========================================
REM 阶段4: 扩展功能
REM ========================================
echo [阶段4/5] 部署扩展功能...

REM 4.1 Lua脚本 - 核心18键脚本
echo   - 部署Lua脚本 (18键核心)...
adb shell mkdir -p %RIME_DIR%/lua
adb push lua/sharedkey_shuangpin_precise_input_processor.lua %RIME_DIR%/lua
adb push lua/sharedkey_shuangpin_precise_input_filter.lua %RIME_DIR%/lua
adb push lua/sharedkey_shuangpin_auxcode_processor.lua %RIME_DIR%/lua
adb push lua/sharedkey_shuangpin_auxcode_filter.lua %RIME_DIR%/lua

REM 4.2 Lua脚本 - 通用翻译器
echo   - 部署Lua脚本 (通用翻译器)...
adb push lua/date_translator.lua %RIME_DIR%/lua
adb push lua/lunar.lua %RIME_DIR%/lua
adb push lua/unicode.lua %RIME_DIR%/lua
adb push lua/number_translator.lua %RIME_DIR%/lua
adb push lua/calculator.lua %RIME_DIR%/lua

REM 4.3 Lua脚本 - 通用过滤器
echo   - 部署Lua脚本 (通用过滤器)...
adb push lua/pro_comment_format.lua %RIME_DIR%/lua
adb push lua/is_in_user_dict.lua %RIME_DIR%/lua

REM 4.4 Lua依赖库
echo   - 部署Lua依赖库 (sbxlm)...
adb shell mkdir -p %RIME_DIR%/lua/sbxlm
adb push lua/sbxlm/lib.lua %RIME_DIR%/lua/sbxlm

REM 4.5 OpenCC配置文件
echo   - 部署OpenCC配置...
adb shell mkdir -p %RIME_DIR%/opencc
adb push opencc/moqi_chaifen.json %RIME_DIR%/opencc
adb push opencc/moqi_chaifen.txt %RIME_DIR%/opencc
adb push opencc/moqi_chaifen_all.json %RIME_DIR%/opencc
adb push opencc/moqi_chaifen_all.txt %RIME_DIR%/opencc
adb push opencc/chinese_english.json %RIME_DIR%/opencc
adb push opencc/chinese_english.txt %RIME_DIR%/opencc
adb push opencc/emoji.json %RIME_DIR%/opencc
adb push opencc/emoji.txt %RIME_DIR%/opencc
adb push opencc/martian.json %RIME_DIR%/opencc
adb push opencc/martian.txt %RIME_DIR%/opencc

REM 4.6 自定义短语
echo   - 部署自定义短语...
adb shell mkdir -p %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_3_code.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_kf.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_mqzg.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_super_1jian.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_super_2jian.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_super_3jian.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_super_3jian_no_conflict.txt %RIME_DIR%/custom_phrase
adb push custom_phrase/custom_phrase_super_4jian_no_conflict.txt %RIME_DIR%/custom_phrase

echo [阶段4/5] 完成
echo.

REM ========================================
REM 阶段5: 触发 Trime 重新部署
REM ========================================
echo [阶段5/5] 触发 Trime 重新部署...
REM 使用新的 action (Trime v3.2.15+)
adb shell am broadcast -a com.osfans.trime.action.DEPLOY
echo.
echo 注意：
echo - 广播已发送（result=0 是正常现象，Android 广播不返回结果）
echo - 部署过程需要约 20 秒，请耐心等待
echo - 如需确认部署结果，请查看 Trime 应用或日志
REM 旧版本使用: adb shell am broadcast -a com.osfans.trime.deploy (已废弃)
echo [阶段5/5] 完成
echo.

echo ========================================
echo 部署完成！
echo ========================================
