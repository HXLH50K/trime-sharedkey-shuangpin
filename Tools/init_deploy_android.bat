@echo off
REM ========================================
REM First-time deploy of Rime config to Android device.
REM Covers moqi_xh-18key.schema.yaml + shouxin_18key.trime.yaml
REM and all their dependencies. Incremental: does not wipe existing files.
REM ========================================

setlocal EnableDelayedExpansion

pushd "%~dp0\.." || (echo [ERROR] Cannot cd to repo root.& exit /b 1)

set "RIME_DIR=/sdcard/rime"
set "FAILED=0"

echo ========================================
echo First-time deploy to Android
echo Target: %RIME_DIR%
echo ========================================
echo.

call :check_adb || goto :fail
call :check_device || goto :fail

REM ----------------------------------------
echo [1/5] Preparing target directory (incremental)...

REM Bail if target path exists as a regular file rather than a directory.
for /f %%a in ('adb shell "if [ -f %RIME_DIR% ]; then echo FILE; fi"') do set "PATH_KIND=%%a"
if "!PATH_KIND!"=="FILE" (
    echo [ERROR] %RIME_DIR% exists as a regular file. Remove it manually and retry.
    goto :fail
)
call :adb_mkdir "%RIME_DIR%"
echo   done.
echo.

REM ----------------------------------------
echo [2/5] Pushing base config and dictionaries...
call :push_file "moqi.yaml"                    "%RIME_DIR%"
call :push_file "symbols_caps_v.yaml"          "%RIME_DIR%"
call :push_file "shouxin_18key.trime.yaml"     "%RIME_DIR%"

echo   - moqi dict (cn_dicts_moqi/)
call :adb_mkdir "%RIME_DIR%/cn_dicts_moqi"
call :push_file "cn_dicts_moqi/8105.dict.yaml"   "%RIME_DIR%/cn_dicts_moqi"
call :push_file "cn_dicts_moqi/41448.dict.yaml"  "%RIME_DIR%/cn_dicts_moqi"
call :push_file "cn_dicts_moqi/base.dict.yaml"   "%RIME_DIR%/cn_dicts_moqi"
call :push_file "cn_dicts_moqi/ext.dict.yaml"    "%RIME_DIR%/cn_dicts_moqi"
call :push_file "cn_dicts_moqi/cell.dict.yaml"   "%RIME_DIR%/cn_dicts_moqi"

echo   - common dict (cn_dicts_common/)
call :adb_mkdir "%RIME_DIR%/cn_dicts_common"
call :push_file "cn_dicts_common/user.dict.yaml"         "%RIME_DIR%/cn_dicts_common"
call :push_file "cn_dicts_common/changcijian.dict.yaml"  "%RIME_DIR%/cn_dicts_common"
call :push_file "cn_dicts_common/changcijian3.dict.yaml" "%RIME_DIR%/cn_dicts_common"

echo   - root dictionaries
call :push_file "moqi.extended.dict.yaml"      "%RIME_DIR%"
call :push_file "moqi_big.extended.dict.yaml"  "%RIME_DIR%"

echo   - dependency dictionaries
call :push_file "easy_en.dict.yaml"            "%RIME_DIR%"
call :push_file "jp_sela.dict.yaml"            "%RIME_DIR%"
call :push_file "emoji.dict.yaml"              "%RIME_DIR%"
call :push_file "cangjie5.dict.yaml"           "%RIME_DIR%"
call :push_file "radical_flypy.dict.yaml"      "%RIME_DIR%"
call :push_file "reverse_moqima.dict.yaml"     "%RIME_DIR%"
echo.

REM ----------------------------------------
echo [3/5] Pushing schemas...
call :push_file "moqi_xh-18key.schema.yaml"    "%RIME_DIR%"
call :push_file "emoji.schema.yaml"            "%RIME_DIR%"
call :push_file "easy_en.schema.yaml"          "%RIME_DIR%"
call :push_file "jp_sela.schema.yaml"          "%RIME_DIR%"
call :push_file "moqi_big.schema.yaml"         "%RIME_DIR%"
echo.

REM ----------------------------------------
echo [4/5] Pushing extensions (lua / opencc / custom_phrase)...
call :adb_mkdir "%RIME_DIR%/lua/sbxlm"

echo   - 18-key core lua
call :push_file "lua/sharedkey_shuangpin_precise_input_processor.lua" "%RIME_DIR%/lua"
call :push_file "lua/sharedkey_shuangpin_precise_input_filter.lua"    "%RIME_DIR%/lua"
call :push_file "lua/sharedkey_shuangpin_auxcode_processor.lua"       "%RIME_DIR%/lua"
call :push_file "lua/sharedkey_shuangpin_auxcode_filter.lua"          "%RIME_DIR%/lua"

echo   - common translators
call :push_file "lua/date_translator.lua"   "%RIME_DIR%/lua"
call :push_file "lua/lunar.lua"             "%RIME_DIR%/lua"
call :push_file "lua/unicode.lua"           "%RIME_DIR%/lua"
call :push_file "lua/number_translator.lua" "%RIME_DIR%/lua"
call :push_file "lua/calculator.lua"        "%RIME_DIR%/lua"

echo   - common filters
call :push_file "lua/pro_comment_format.lua" "%RIME_DIR%/lua"
call :push_file "lua/is_in_user_dict.lua"    "%RIME_DIR%/lua"

echo   - sbxlm lib
call :push_file "lua/sbxlm/lib.lua" "%RIME_DIR%/lua/sbxlm"

echo   - opencc
call :adb_mkdir "%RIME_DIR%/opencc"
call :push_file "opencc/moqi_chaifen.json"     "%RIME_DIR%/opencc"
call :push_file "opencc/moqi_chaifen.txt"      "%RIME_DIR%/opencc"
call :push_file "opencc/moqi_chaifen_all.json" "%RIME_DIR%/opencc"
call :push_file "opencc/moqi_chaifen_all.txt"  "%RIME_DIR%/opencc"
call :push_file "opencc/chinese_english.json"  "%RIME_DIR%/opencc"
call :push_file "opencc/chinese_english.txt"   "%RIME_DIR%/opencc"
call :push_file "opencc/emoji.json"            "%RIME_DIR%/opencc"
call :push_file "opencc/emoji.txt"             "%RIME_DIR%/opencc"
call :push_file "opencc/martian.json"          "%RIME_DIR%/opencc"
call :push_file "opencc/martian.txt"           "%RIME_DIR%/opencc"

echo   - custom phrases
call :adb_mkdir "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase.txt"                          "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_3_code.txt"                   "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_kf.txt"                       "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_mqzg.txt"                     "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_super_1jian.txt"              "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_super_2jian.txt"              "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_super_3jian.txt"              "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_super_3jian_no_conflict.txt"  "%RIME_DIR%/custom_phrase"
call :push_file "custom_phrase/custom_phrase_super_4jian_no_conflict.txt"  "%RIME_DIR%/custom_phrase"
echo.

REM ----------------------------------------
echo [5/5] Broadcasting Trime deploy intent...
adb shell am broadcast -a com.osfans.trime.action.DEPLOY
if errorlevel 1 (
    echo [WARN] Broadcast command failed.
    set /a FAILED+=1
)
echo.
echo Note:
echo - Trime processes the broadcast asynchronously (~20s).
echo - Check the Trime app or its log to confirm deployment.
echo.

echo ========================================
if "!FAILED!"=="0" (
    echo Initial deploy finished successfully.
    set "EXITCODE=0"
) else (
    echo Initial deploy finished with !FAILED! failure^(s^).
    set "EXITCODE=1"
)
echo ========================================
popd
endlocal & exit /b %EXITCODE%

:fail
popd
endlocal & exit /b 1

:check_adb
where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb not found in PATH.
    exit /b 1
)
exit /b 0

:check_device
for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
    if "%%b"=="device" exit /b 0
)
echo [ERROR] No authorized adb device connected.
exit /b 1

:adb_mkdir
adb shell "mkdir -p %~1" >nul
if errorlevel 1 (
    echo [WARN] mkdir failed: %~1
    set /a FAILED+=1
)
exit /b 0

:push_file
if not exist "%~1" (
    echo [ERROR] Source missing: %~1
    set /a FAILED+=1
    exit /b 1
)
adb push "%~1" "%~2" >nul
if errorlevel 1 (
    echo [ERROR] push failed: %~1
    set /a FAILED+=1
)
exit /b 0
