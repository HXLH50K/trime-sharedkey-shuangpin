-- sharedkey_shuangpin_precise_input_processor.lua
-- 共键双拼精确输入处理器 v2：支持18键形码引导键方案
--
-- 功能：
-- 1. 拦截大写字母输入（A-Z），记录为精确输入位置，转换为小写发送
-- 2. 处理形码引导键 [ 的输入
-- 3. 记录输入结构（音码/形码边界）
--
-- 使用场景：18键共键双拼模糊输入时
-- - 点击发送小写字母（触发模糊匹配）
-- - 滑动发送大写字母（精确匹配，消除共键模糊）
-- - 点击引导键发送 [（进入形码输入）
--
-- 配合 sharedkey_shuangpin_precise_input_filter.lua 使用
-- 参考：lua/sbxlm/upper_case.lua

local rime = require "sbxlm.lib"

local function processor(key, env)
    -- 只处理按键按下事件，忽略释放、Alt、Ctrl、Caps
    if key:release() or key:alt() or key:ctrl() or key:caps() then
        return rime.process_results.kNoop
    end
    
    local keycode = key.keycode
    local context = env.engine.context
    
    -- 如果是 ASCII 模式（英文模式），不拦截任何按键
    if context:get_option("ascii_mode") then
        return rime.process_results.kNoop
    end
    
    -- 检查是否是大写字母 (A=65, Z=90)
    if keycode >= 65 and keycode <= 90 then
        -- 转换为小写字母
        local char = utf8.char(keycode + 32)
        
        -- 获取当前输入长度（新字母将添加到这个位置）
        local pos = #context.input + 1
        
        -- 获取或初始化精确输入记录
        local precise_map = context:get_property("precise_input_map") or ""
        
        -- 记录这个位置是精确输入
        -- 格式: "1,3,5" 表示第1、3、5个字符是精确输入
        if #precise_map > 0 then
            precise_map = precise_map .. "," .. tostring(pos)
        else
            precise_map = tostring(pos)
        end
        context:set_property("precise_input_map", precise_map)
        
        -- 追加小写字母到输入
        context:push_input(char)
        
        return rime.process_results.kAccepted
    end
    
    -- 检查是否是形码引导键 [ (keycode = 91)
    if keycode == 91 then
        local input = context.input or ""
        
        -- 防止连续输入多个 [
        if input:sub(-1) == "[" then
            return rime.process_results.kAccepted
        end
        
        -- 记录形码引导位置（用于解析输入结构）
        local aux_positions = context:get_property("auxiliary_positions") or ""
        local pos = #input + 1
        if #aux_positions > 0 then
            aux_positions = aux_positions .. "," .. tostring(pos)
        else
            aux_positions = tostring(pos)
        end
        context:set_property("auxiliary_positions", aux_positions)
        
        -- 发送 [ 到输入
        context:push_input("[")
        
        return rime.process_results.kAccepted
    end
    
    -- 检查是否是退格键 (BackSpace = 0xff08 = 65288)
    if keycode == 65288 or keycode == 0xff08 then
        local input = context.input or ""
        local input_len = #input
        
        if input_len > 0 then
            -- 更新精确输入记录
            local precise_map = context:get_property("precise_input_map") or ""
            if #precise_map > 0 then
                local positions = {}
                for p in string.gmatch(precise_map, "(%d+)") do
                    local pos_num = tonumber(p)
                    if pos_num < input_len then
                        table.insert(positions, pos_num)
                    end
                end
                context:set_property("precise_input_map", table.concat(positions, ","))
            end
            
            -- 更新形码引导位置记录
            local aux_positions = context:get_property("auxiliary_positions") or ""
            if #aux_positions > 0 then
                local positions = {}
                for p in string.gmatch(aux_positions, "(%d+)") do
                    local pos_num = tonumber(p)
                    if pos_num < input_len then
                        table.insert(positions, pos_num)
                    end
                end
                context:set_property("auxiliary_positions", table.concat(positions, ","))
            end
        end
        
        -- 让其他 processor 处理退格
        return rime.process_results.kNoop
    end
    
    -- 检查是否是 Escape (0xff1b = 65307)
    if keycode == 65307 or keycode == 0xff1b then
        -- 清空所有记录
        context:set_property("precise_input_map", "")
        context:set_property("auxiliary_positions", "")
        return rime.process_results.kNoop
    end
    
    -- 检查是否是空格或回车（提交时清空记录）
    if keycode == 32 or keycode == 65293 or keycode == 0xff0d then
        -- 提交后清空记录（由 filter 或其他机制处理）
        -- 这里不清空，因为可能是选字而非提交
    end
    
    -- 其他按键不处理
    return rime.process_results.kNoop
end

return processor
