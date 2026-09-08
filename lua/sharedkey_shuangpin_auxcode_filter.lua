-- sharedkey_shuangpin_auxcode_filter.lua
-- 共键双拼形码过滤器：根据辅助码过滤候选
--
-- 方案设计：
-- - 无引导符：纯音码(2位) 或 三码(音码2+辅助码1)
-- - 有引导符[：音码2+辅助码2
--
-- 功能：根据辅助码过滤候选，支持共键模糊匹配
--
-- 配合 sharedkey_shuangpin_auxcode_processor.lua 使用

-- 默认共键映射
local default_fuzzy_pairs = {
    w = "e", e = "w",  -- WE 共键
    r = "t", t = "r",  -- RT 共键
    i = "o", o = "i",  -- IO 共键
    s = "d", d = "s",  -- SD 共键
    f = "g", g = "f",  -- FG 共键
    j = "k", k = "j",  -- JK 共键
    x = "c", c = "x",  -- XC 共键
    b = "n", n = "b",  -- BN 共键
}

-- 配置
local MAX_CANDIDATES = 200  -- 只处理前N个候选
local fuzzy_pairs = default_fuzzy_pairs
local reversedb = nil
local lookup_cache = {}  -- 反查缓存

-- 从配置文件加载模糊对
local function load_fuzzy_pairs(config)
    local pairs_list = config:get_list("precise_input/fuzzy_pairs")
    if pairs_list and pairs_list.size > 0 then
        fuzzy_pairs = {}
        for i = 0, pairs_list.size - 1 do
            local pair_str = pairs_list:get_value_at(i):get_string()
            if pair_str and #pair_str >= 2 then
                local c1, c2 = pair_str:sub(1, 1):lower(), pair_str:sub(2, 2):lower()
                fuzzy_pairs[c1] = c2
                fuzzy_pairs[c2] = c1
            end
        end
    end
end

-- 带缓存的反查
local function cached_lookup(char)
    local cached = lookup_cache[char]
    if cached ~= nil then
        return cached
    end
    
    if not reversedb then
        lookup_cache[char] = { pinyin = "", shape = "" }
        return lookup_cache[char]
    end
    
    local result = reversedb:lookup(char) or ""
    -- 解析格式：pinyin[shape 或 pinyin
    local pinyin, shape = result:match("^([^%[%s]+)%[?(%w*)")
    
    lookup_cache[char] = {
        pinyin = (pinyin or ""):lower(),
        shape = (shape or ""):lower()
    }
    return lookup_cache[char]
end

-- 简化版 UTF-8 字符遍历
local function each_char(str)
    local chars = {}
    local i = 1
    while i <= #str do
        local b = str:byte(i)
        local len = b < 128 and 1 or b < 224 and 2 or b < 240 and 3 or 4
        table.insert(chars, str:sub(i, i + len - 1))
        i = i + len
    end
    return chars
end

-- 解析无引导符输入（三码模式）
-- 规则：每2位音码 + 可选1位辅助码
-- 例如：syf -> {pinyin="sy", shape="f"}
--       syfui -> {pinyin="sy", shape="f"}, {pinyin="ui", shape=""}
local function parse_without_bracket(input)
    local segments = {}
    local i = 1
    local len = #input
    
    while i <= len do
        local segment = { pinyin = "", shape = "" }
        
        -- 读取2位音码
        if i + 1 <= len then
            segment.pinyin = input:sub(i, i + 1)
            i = i + 2
        else
            -- 不足2位，等待更多输入
            segment.pinyin = input:sub(i)
            segment.incomplete = true
            i = len + 1
            table.insert(segments, segment)
            break
        end
        
        -- 检查是否有第3位（辅助码）
        if i <= len then
            local third = input:sub(i, i)
            if third:match("[a-z]") then
                -- 后面还有字符，判断这是辅助码还是新音码
                if i + 1 <= len then
                    -- 后面还有2位以上，这个是辅助码
                    segment.shape = third
                    i = i + 1
                elseif i == len then
                    -- 这是最后一位，作为辅助码
                    segment.shape = third
                    i = i + 1
                end
            end
        end
        
        table.insert(segments, segment)
    end
    
    return segments
end

-- 解析有引导符输入（引导符模式）
-- 规则：引导符前为音码，引导符后贪心匹配辅助码（1-2位）
local function parse_with_bracket(input)
    local segments = {}
    local current_segment = nil
    local i = 1
    local len = #input
    local in_shape = false
    
    while i <= len do
        local c = input:sub(i, i)
        
        if c == "[" then
            -- 遇到引导符，进入辅助码模式
            in_shape = true
            i = i + 1
        elseif in_shape then
            -- 在辅助码模式中
            if current_segment then
                -- 贪心匹配辅助码
                if #current_segment.shape < 2 then
                    current_segment.shape = current_segment.shape .. c
                    i = i + 1
                    -- 辅助码满2位后退出
                    if #current_segment.shape >= 2 then
                        in_shape = false
                    end
                else
                    -- 辅助码已满，这是新的音码
                    in_shape = false
                    current_segment = nil
                    -- 不增加 i，下次循环继续处理
                end
            else
                -- 没有当前 segment，这不应该发生
                in_shape = false
            end
        else
            -- 音码模式
            if current_segment and #current_segment.pinyin < 2 then
                current_segment.pinyin = current_segment.pinyin .. c
                i = i + 1
            else
                -- 开始新 segment
                if current_segment then
                    table.insert(segments, current_segment)
                end
                current_segment = { pinyin = c, shape = "" }
                i = i + 1
            end
        end
    end
    
    -- 添加最后一个 segment
    if current_segment and #current_segment.pinyin > 0 then
        -- 标记不完整的 segment（音码不足2位）
        if #current_segment.pinyin < 2 then
            current_segment.incomplete = true
        end
        table.insert(segments, current_segment)
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

-- 检查字符是否匹配（考虑共键模糊）
local function char_matches(user_char, cand_char, precise_positions, pos)
    if not user_char or not cand_char then
        return false
    end
    
    user_char = user_char:lower()
    cand_char = cand_char:lower()
    
    if user_char == cand_char then
        return true
    end
    
    -- 如果是精确输入位置，不允许模糊
    if precise_positions and precise_positions[pos] then
        return false
    end
    
    -- 检查共键模糊
    local fuzzy = fuzzy_pairs[user_char]
    return fuzzy and fuzzy == cand_char
end

-- 检查辅助码是否匹配
local function shape_matches(user_shape, cand_shape, precise_positions, shape_start_pos)
    if #user_shape == 0 then
        return true  -- 没有输入辅助码，不过滤
    end
    
    -- 检查每一位辅助码
    for i = 1, #user_shape do
        local user_c = user_shape:sub(i, i)
        local cand_c = cand_shape:sub(i, i)
        
        if #cand_c == 0 then
            -- 候选辅助码位数不够，但用户输入了更多
            -- 如果是第一位就没有，则不匹配
            -- 如果是第二位没有，但第一位匹配了，可以通过（部分匹配）
            if i == 1 then
                return false
            else
                return true  -- 部分匹配通过
            end
        end
        
        if not char_matches(user_c, cand_c, precise_positions, shape_start_pos + i - 1) then
            return false
        end
    end
    
    return true
end

-- 解析精确输入位置
local function parse_precise_map(map_str)
    if not map_str or #map_str == 0 then
        return nil
    end
    local positions = {}
    for pos in map_str:gmatch("(%d+)") do
        positions[tonumber(pos)] = true
    end
    return next(positions) and positions or nil
end

-- 检查候选是否匹配
local function matches_input(cand_text, segments, precise_positions, has_bracket)
    local chars = each_char(cand_text)
    
    if #chars == 0 then
        return true
    end
    
    -- 对于每个汉字，检查是否匹配对应的 segment
    local input_pos = 1  -- 追踪在原始输入中的位置
    
    for seg_idx, seg in ipairs(segments) do
        local char = chars[seg_idx]
        if not char then
            break  -- 候选字数少于 segment 数，通过
        end
        
        -- 跳过不完整的 segment
        if seg.incomplete then
            break
        end
        
        local lookup = cached_lookup(char)
        local cand_pinyin = lookup.pinyin
        local cand_shape = lookup.shape
        
        -- 检查音码匹配
        if #seg.pinyin >= 1 and #cand_pinyin >= 1 then
            if not char_matches(seg.pinyin:sub(1, 1), cand_pinyin:sub(1, 1), precise_positions, input_pos) then
                return false
            end
        end
        
        if #seg.pinyin >= 2 and #cand_pinyin >= 2 then
            if not char_matches(seg.pinyin:sub(2, 2), cand_pinyin:sub(2, 2), precise_positions, input_pos + 1) then
                return false
            end
        end
        
        -- 检查辅助码匹配
        if #seg.shape > 0 then
            local shape_start = input_pos + #seg.pinyin
            if has_bracket then
                shape_start = shape_start + 1  -- +1 for [
            end
            if not shape_matches(seg.shape, cand_shape, precise_positions, shape_start) then
                return false
            end
        end
        
        -- 更新输入位置
        input_pos = input_pos + #seg.pinyin
        if #seg.shape > 0 then
            if has_bracket then
                input_pos = input_pos + 1 + #seg.shape  -- +1 for [
            else
                input_pos = input_pos + #seg.shape
            end
        end
    end
    
    return true
end

-- 初始化
local function init(env)
    local config = env.engine.schema.config
    local dict = config:get_string("translator/dictionary") or env.engine.schema.schema_id
    ---@diagnostic disable-next-line: undefined-global
    reversedb = ReverseLookup(dict)
    load_fuzzy_pairs(config)
end

-- 调试：序列化 segments
local function serialize_segments(segments)
    local parts = {}
    for _, seg in ipairs(segments) do
        local part = string.format("{py=%s,sh=%s%s}",
            seg.pinyin, seg.shape, seg.incomplete and ",inc" or "")
        table.insert(parts, part)
    end
    return "[" .. table.concat(parts, ", ") .. "]"
end

-- 过滤函数
local function filter(input, env)
    -- 延迟初始化
    if not reversedb then
        init(env)
    end
    
    local context = env.engine.context
    local user_input = context.input or ""
    local precise_map = context:get_property("precise_input_map") or ""
    local precise_positions = parse_precise_map(precise_map)
    
    -- 输入太短时不过滤
    if #user_input < 3 then
        for cand in input:iter() do
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        return
    end
    
    -- 解析用户输入
    local has_bracket = user_input:find("%[") ~= nil
    local segments = parse_input(user_input)
    
    -- 调试日志
    local debug_info = string.format("auxcode_filter: input='%s' segments=%s",
        user_input, serialize_segments(segments))
    ---@diagnostic disable-next-line: undefined-global
    log.info(debug_info)
    
    -- 如果没有辅助码，不过滤
    local has_auxcode = false
    for _, seg in ipairs(segments) do
        if #seg.shape > 0 then
            has_auxcode = true
            break
        end
    end
    
    if not has_auxcode and not precise_positions then
        for cand in input:iter() do
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        return
    end
    
    -- 清空缓存（每次新输入时）
    lookup_cache = {}
    
    local count = 0
    for cand in input:iter() do
        count = count + 1
        
        -- 超过限制，直接通过
        if count > MAX_CANDIDATES then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        elseif matches_input(cand.text, segments, precise_positions, has_bracket) then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        -- 不匹配的候选不 yield
    end
end

return filter
