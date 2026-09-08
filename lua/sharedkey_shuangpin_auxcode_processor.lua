-- sharedkey_shuangpin_auxcode_processor.lua
-- 共键双拼形码处理器：解析三码/四码输入结构
--
-- 方案设计：
-- - 无引导符：纯音码(2位) 或 三码(音码2+辅助码1)
-- - 有引导符[：音码2+辅助码2，用户可主动分词
--
-- 配合 sharedkey_shuangpin_auxcode_filter.lua 使用

local rime = require "sbxlm.lib"

-- 共键对配置
local FUZZY_PAIRS = {
    w = "e", e = "w",
    r = "t", t = "r",
    i = "o", o = "i",
    s = "d", d = "s",
    f = "g", g = "f",
    j = "k", k = "j",
    x = "c", c = "x",
    b = "n", n = "b"
}

-- 解析无引导符的输入（三码模式）
-- 规则：每2位音码 + 可选1位辅助码
-- 例如：syf -> {pinyin="sy", shape="f"}
--       syfui -> {pinyin="sy", shape="f"}, {pinyin="ui", shape=""}
local function parse_without_bracket(input)
    local segments = {}
    local i = 1
    local len = #input
    
    while i <= len do
        local segment = { pinyin = "", shape = "", start_pos = i }
        
        -- 读取2位音码
        if i + 1 <= len then
            segment.pinyin = input:sub(i, i + 1)
            i = i + 2
        else
            -- 不足2位，等待更多输入
            segment.pinyin = input:sub(i)
            segment.incomplete = true
            i = len + 1
        end
        
        -- 检查是否有第3位（形码）
        if i <= len and not segment.incomplete then
            local third = input:sub(i, i)
            -- 第3位作为形码
            if third:match("[a-z]") then
                -- 检查是否是下一个音码的开始
                -- 如果后面还有2位以上，则这个是形码
                -- 如果后面只有1位，则这个可能是形码也可能是新音码开始
                if i + 2 <= len then
                    -- 后面还有足够字符，这个是形码
                    segment.shape = third
                    i = i + 1
                elseif i + 1 == len then
                    -- 后面只有1位，可能是：形码+不完整音码 或 完整音码的第1位
                    -- 优先作为辅助码
                    segment.shape = third
                    i = i + 1
                else
                    -- 这是最后一位，作为形码
                    segment.shape = third
                    i = i + 1
                end
            end
        end
        
        table.insert(segments, segment)
    end
    
    return segments
end

-- 解析有引导符的输入（引导符模式）
-- 规则：引导符前为音码（2位一组），引导符后贪心匹配辅助码（1-2位）
-- 例如：sy[ff -> {pinyin="sy", shape="ff"}
--       sy[ffu -> {pinyin="sy", shape="ff"}, {pinyin="u", incomplete=true}
local function parse_with_bracket(input)
    local segments = {}
    local parts = {}
    
    -- 按 [ 分割
    local last_end = 1
    for bracket_pos in input:gmatch("()%[") do
        if bracket_pos > last_end then
            table.insert(parts, {
                text = input:sub(last_end, bracket_pos - 1),
                has_bracket_after = true,
                start_pos = last_end
            })
        end
        last_end = bracket_pos + 1
    end
    if last_end <= #input then
        table.insert(parts, {
            text = input:sub(last_end),
            has_bracket_after = false,
            start_pos = last_end,
            is_after_bracket = #parts > 0  -- 是否在某个 [ 之后
        })
    end
    
    for idx, part in ipairs(parts) do
        if idx == 1 and not input:match("^%[") then
            -- 第一部分是引导符之前的音码
            local i = 1
            while i <= #part.text do
                local segment = { pinyin = "", shape = "", start_pos = part.start_pos + i - 1 }
                if i + 1 <= #part.text then
                    segment.pinyin = part.text:sub(i, i + 1)
                    i = i + 2
                else
                    segment.pinyin = part.text:sub(i)
                    segment.incomplete = true
                    i = #part.text + 1
                end
                table.insert(segments, segment)
            end
        elseif part.is_after_bracket or idx > 1 then
            -- [ 后的部分：贪心匹配辅助码
            local text = part.text
            local shape = ""
            local rest_start = 1
            
            if #text >= 2 then
                -- 贪心匹配2位辅助码
                shape = text:sub(1, 2)
                rest_start = 3
            elseif #text == 1 then
                -- 只有1位，可能是辅助码，也可能在等待第2位
                shape = text:sub(1, 1)
                rest_start = 2
            end
            
            -- 将辅助码附加到前一个 segment
            if #segments > 0 then
                segments[#segments].shape = shape
            end
            
            -- 解析剩余部分作为新的音码
            local rest = text:sub(rest_start)
            if #rest > 0 then
                local i = 1
                while i <= #rest do
                    local segment = { pinyin = "", shape = "", start_pos = part.start_pos + rest_start + i - 2 }
                    if i + 1 <= #rest then
                        segment.pinyin = rest:sub(i, i + 1)
                        i = i + 2
                    else
                        segment.pinyin = rest:sub(i)
                        segment.incomplete = true
                        i = #rest + 1
                    end
                    table.insert(segments, segment)
                end
            end
        end
    end
    
    return segments
end

-- 主解析函数
local function parse_input(input)
    if not input or #input == 0 then
        return {}
    end
    
    if input:find("%[") then
        return parse_with_bracket(input)
    else
        return parse_without_bracket(input)
    end
end

-- 将解析结果序列化为字符串（供 context property 存储）
local function serialize_segments(segments)
    local parts = {}
    for _, seg in ipairs(segments) do
        local part = seg.pinyin
        if seg.shape and #seg.shape > 0 then
            part = part .. "[" .. seg.shape
        end
        if seg.incomplete then
            part = part .. "..."
        end
        table.insert(parts, part)
    end
    return table.concat(parts, "|")
end

-- 处理器主函数
local function processor(key, env)
    -- 只处理按键按下事件
    if key:release() or key:alt() or key:ctrl() or key:caps() then
        return rime.process_results.kNoop
    end
    
    local keycode = key.keycode
    local context = env.engine.context
    
    -- 如果是 ASCII 模式，不处理
    if context:get_option("ascii_mode") then
        return rime.process_results.kNoop
    end
    
    -- 获取当前输入
    local input = context.input or ""
    
    -- 只有在有输入时才解析
    if #input > 0 then
        -- 解析输入结构
        local segments = parse_input(input)
        
        -- 存储解析结果供 filter 使用
        local serialized = serialize_segments(segments)
        context:set_property("auxcode_segments", serialized)
        
        -- 存储原始输入长度（用于判断是否需要重新解析）
        context:set_property("auxcode_input_len", tostring(#input))
    else
        -- 输入为空时清除解析结果
        context:set_property("auxcode_segments", "")
        context:set_property("auxcode_input_len", "0")
    end
    
    -- 不拦截任何按键，让其他 processor 继续处理
    return rime.process_results.kNoop
end

return processor
