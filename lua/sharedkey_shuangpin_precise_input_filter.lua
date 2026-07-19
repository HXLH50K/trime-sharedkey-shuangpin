-- sharedkey_shuangpin_precise_input_filter.lua
-- 共键双拼精确输入过滤器 v10：支持18键形码引导键方案
--
-- 功能：
-- 1. 根据精确输入位置过滤不匹配的候选（消除共键模糊）
-- 2. 解析 音码[形码 结构，正确匹配候选
-- 3. 支持音码和形码分别的共键模糊
--
-- 输入格式：
--   音码1[形码1 音码2[形码2 ...
--   其中：音码=2字母（共键双拼），形码=1-2字母（墨奇辅助码）
--
-- 配合 sharedkey_shuangpin_precise_input_processor.lua 使用

-- 默认的18键共键映射
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

local fuzzy_pairs = default_fuzzy_pairs
local reversedb = nil
local memory = nil
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

    local codes = {}
    if not reversedb then
        lookup_cache[char] = codes
        return codes
    end

    local result = reversedb:lookup(char) or ""
    -- ReverseLookup 可能返回空格分隔的多组编码。
    for code in result:gmatch("%S+") do
        local pinyin, auxiliary = code:match("^([^%[]+)%[?(%w*)$")
        if pinyin then
            table.insert(codes, {
                pinyin = pinyin:lower(),
                auxiliary = (auxiliary or ""):lower()
            })
        end
    end

    lookup_cache[char] = codes
    return codes
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

local function span_has_precise_position(precise_positions, input_start, input_end)
    if not precise_positions then
        return false
    end
    for pos in pairs(precise_positions) do
        if pos > input_start and pos <= input_end then
            return true
        end
    end
    return false
end

-- 解析用户输入为结构化数据
-- 返回: { segments = { {pinyin="xx", auxiliary="xx"}, ... } }
local function parse_input(input)
    local result = { segments = {} }
    local current = { pinyin = "", auxiliary = "" }
    local in_auxiliary = false
    local pinyin_buffer = ""

    for i = 1, #input do
        local c = input:sub(i, i)

        if c == "[" then
            -- 遇到引导键，之前的拼音部分完成
            if #pinyin_buffer >= 2 then
                current.pinyin = pinyin_buffer:sub(1, 2)
                pinyin_buffer = pinyin_buffer:sub(3)  -- 保留多余部分
            end
            in_auxiliary = true
        elseif c == "'" then
            -- 分词符，完成当前segment
            if #current.pinyin > 0 then
                table.insert(result.segments, current)
            end
            current = { pinyin = "", auxiliary = "" }
            in_auxiliary = false
            pinyin_buffer = ""
        elseif in_auxiliary then
            current.auxiliary = current.auxiliary .. c
            -- 形码最多2位
            if #current.auxiliary >= 2 then
                table.insert(result.segments, current)
                current = { pinyin = "", auxiliary = "" }
                in_auxiliary = false
                -- 处理之前缓存的多余拼音
                if #pinyin_buffer > 0 then
                    current.pinyin = pinyin_buffer
                    pinyin_buffer = ""
                end
            end
        else
            -- 拼音输入
            if #current.pinyin < 2 then
                current.pinyin = current.pinyin .. c
            else
                -- 拼音已满2位，检查是否开始新segment
                if #current.auxiliary > 0 then
                    -- 已有形码，开始新segment
                    table.insert(result.segments, current)
                    current = { pinyin = c, auxiliary = "" }
                else
                    -- 无形码，继续累积（可能后面有[）
                    pinyin_buffer = pinyin_buffer .. c
                end
            end
        end
    end

    -- 处理最后的segment
    if #current.pinyin > 0 or #current.auxiliary > 0 then
        table.insert(result.segments, current)
    end

    -- 处理剩余的纯双拼音节
    if #pinyin_buffer > 0 then
        for i = 1, #pinyin_buffer, 2 do
            local seg = { pinyin = pinyin_buffer:sub(i, i+1), auxiliary = "" }
            table.insert(result.segments, seg)
        end
    end

    return result
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

-- 检查单个字符是否匹配（考虑模糊和精确）
local function char_matches(user_char, cand_char, is_precise)
    user_char = user_char:lower()
    cand_char = cand_char:lower()

    if user_char == cand_char then
        return true
    end

    -- 如果是精确输入，不允许模糊
    if is_precise then
        return false
    end

    -- 检查共键模糊
    local fuzzy = fuzzy_pairs[user_char]
    return fuzzy and fuzzy == cand_char
end

-- 检查形码是否匹配
local function auxiliary_matches(user_aux, cand_aux, precise_positions, aux_start_pos)
    if #user_aux == 0 then
        return true  -- 没有输入形码，不过滤
    end

    if #cand_aux == 0 then
        return false  -- 候选没有形码，但用户输入了
    end

    -- 检查每一位形码
    for i = 1, #user_aux do
        local user_c = user_aux:sub(i, i)
        local cand_c = cand_aux:sub(i, i)

        if #cand_c == 0 then
            return false  -- 候选形码位数不够
        end

        local pos = aux_start_pos + i  -- 计算在原始输入中的位置
        local is_precise = precise_positions and precise_positions[pos]

        if not char_matches(user_c, cand_c, is_precise) then
            return false
        end
    end

    return true
end

-- 检查候选是否匹配
local function segment_matches_code(seg, lookup, precise_positions, pos)
    local cand_pinyin = lookup.pinyin
    local cand_aux = lookup.auxiliary

    if #seg.pinyin >= 1 and #cand_pinyin >= 1 then
        local is_precise_1 = precise_positions and precise_positions[pos]
        if not char_matches(seg.pinyin:sub(1, 1), cand_pinyin:sub(1, 1), is_precise_1) then
            return false
        end
    end

    if #seg.pinyin >= 2 and #cand_pinyin >= 2 then
        local is_precise_2 = precise_positions and precise_positions[pos + 1]
        if not char_matches(seg.pinyin:sub(2, 2), cand_pinyin:sub(2, 2), is_precise_2) then
            return false
        end
    end

    local aux_start = pos + #seg.pinyin + 1
    return auxiliary_matches(seg.auxiliary, cand_aux, precise_positions, aux_start)
end

local function segment_matches_char(char, seg, precise_positions, pos)
    local lookups = cached_lookup(char)
    if #lookups == 0 then
        return #seg.auxiliary == 0
    end
    for _, lookup in ipairs(lookups) do
        if segment_matches_code(seg, lookup, precise_positions, pos) then
            return true
        end
    end
    return false
end

local function segment_positions(segments, input_start)
    local positions = {}
    local pos = input_start + 1
    for index, seg in ipairs(segments) do
        positions[index] = pos
        pos = pos + #seg.pinyin
        if #seg.auxiliary > 0 then
            pos = pos + 1 + #seg.auxiliary
        end
    end
    return positions
end

local function matches_input(cand_text, parsed_input, precise_positions, input_start)
    local chars = each_char(cand_text)
    local segments = parsed_input.segments
    local positions = segment_positions(segments, input_start)

    if #chars == 0 then
        return true
    end

    for seg_idx, seg in ipairs(segments) do
        local char = chars[seg_idx]
        if not char then
            break
        end
        if not segment_matches_char(char, seg, precise_positions, positions[seg_idx]) then
            return false
        end
    end

    return true
end

local function rebuild_precise_sentence(cand, parsed_input, precise_positions, input_start)
    local chars = each_char(cand.text)
    local segments = parsed_input.segments
    if not memory or #chars ~= #segments or #segments < 2 then
        return nil
    end

    local positions = segment_positions(segments, input_start)
    local mismatch_index = nil
    for index, seg in ipairs(segments) do
        if not segment_matches_char(chars[index], seg, precise_positions, positions[index]) then
            if mismatch_index then
                return nil
            end
            mismatch_index = index
        end
    end
    if not mismatch_index then
        return nil
    end

    local seg = segments[mismatch_index]
    if #seg.pinyin ~= 2 or #seg.auxiliary > 0 then
        return nil
    end

    local rebuilt = {}
    local seen = {}
    memory:dict_lookup(seg.pinyin, false, 0)
    for entry in memory:iter_dict() do
        local replacement_chars = each_char(entry.text)
        local replacement = replacement_chars[1]
        if #replacement_chars == 1
            and not seen[replacement]
            and segment_matches_char(replacement, seg, precise_positions, positions[mismatch_index]) then
            local new_chars = {}
            for index, char in ipairs(chars) do
                new_chars[index] = index == mismatch_index and replacement or char
            end
            local text = table.concat(new_chars)
            if text ~= cand.text then
                seen[replacement] = true
                table.insert(rebuilt, cand:to_shadow_candidate(cand.type, text, cand.comment))
                if #rebuilt >= 6 then
                    break
                end
            end
        end
    end
    return rebuilt
end

-- 初始化
local function init(env)
    local config = env.engine.schema.config
    local dict = config:get_string("translator/dictionary") or env.engine.schema.schema_id
    ---@diagnostic disable-next-line: undefined-global
    reversedb = ReverseLookup(dict)
    ---@diagnostic disable-next-line: undefined-global
    memory = Memory(env.engine, env.engine.schema)
    load_fuzzy_pairs(config)
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

    -- 如果没有形码引导，且没有精确输入，直接返回所有候选
    if not user_input:find("%[") and not precise_positions then
        for cand in input:iter() do
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        return
    end

    -- 清空缓存（每次新输入时）
    lookup_cache = {}

    for cand in input:iter() do
        local input_start = cand.start or 0
        local input_end = cand._end or #user_input
        local candidate_input = user_input:sub(input_start + 1, input_end)
        local parsed = parse_input(candidate_input)
        local needs_filter = candidate_input:find("%[")
            or span_has_precise_position(precise_positions, input_start, input_end)
        local matched = not needs_filter
            or matches_input(cand.text, parsed, precise_positions, input_start)

        if matched then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        elseif needs_filter and input_start == 0 and input_end == #user_input then
            local rebuilt = rebuild_precise_sentence(cand, parsed, precise_positions, input_start)
            if rebuilt then
                for _, rebuilt_cand in ipairs(rebuilt) do
                    ---@diagnostic disable-next-line: undefined-global
                    yield(rebuilt_cand)
                end
            end
        end
        -- 不匹配的候选不 yield
    end
end

return filter
