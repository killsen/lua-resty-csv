
local type          = type
local tostring      = tostring
local setmetatable  = setmetatable
local ipairs        = ipairs
local pairs         = pairs

local _insert       = table.insert
local _remove       = table.remove
local _concat       = table.concat
local _clear        = table.clear
local _newt         = table.new

local _M = { _VERSION = '1.0.1' }
local mt = { __index = _M }

_M.types = {
    Options = {
        delimiter  = "string  ? //字段分隔符（默认逗号）",
        quote_char = "string  ? //引号字符（默认双引号）",
        line_end   = "string  ? //行结束符（默认 \n，Windows 可改为 \r\n）",
        has_header = "boolean ? //解析时是否包含表头（默认否）",
    }
}

-- 默认配置
local DEFAULT_OPTIONS = {
    delimiter  = ',',       -- 字段分隔符（默认逗号）
    quote_char = '"',       -- 引号字符（默认双引号）
    line_end   = '\n',      -- 行结束符（默认 \n，Windows 可改为 \r\n）
    has_header = false,     -- 解析时是否包含表头（默认否）
}

-- 合并用户配置与默认配置
local function merge_options(options)
-- @options?: @Options
-- @return  : @Options

    local opts = {}

    for k, v in pairs(DEFAULT_OPTIONS) do
        opts[k] = v
    end

    if options then
        for k, v in pairs(options) do
            opts[k] = v
        end
    end

    -- 预生成需要检查的特殊字符模式
    opts["escape_pattern"] = '[' .. opts.delimiter .. opts.quote_char .. '\n\r]'

    return opts

end

-- 创建 CSV 处理器实例（支持自定义配置）
function _M.new(options)  --@@
-- @options ?: @Options
    local opts = merge_options(options)
    return setmetatable({ opts = opts }, mt)
end

-- 转义字段（生成 CSV 时使用）
local function escape_field(str, opts)
-- @str     : string | number | boolean | nil
-- @opts    : @Options
-- @return  : string

    if str == nil then return "" end
    if type(str) ~= "string" then return tostring(str) end

    -- 检查是否包含需要转义的字符
    local escape_pattern = opts["escape_pattern"]
    if not str:find(escape_pattern) then return str end

    local quote_char = opts.quote_char

    -- 转义引号（将单个引号替换为两个）
    str = str:gsub(quote_char, quote_char .. quote_char)

    -- 用引号包裹字段
    return quote_char .. str .. quote_char

end

-- 解析 CSV（字符串 → 数组/表）
function _M:parse(csv_str)
-- @csv_str : string
-- @return  : string[][]

    local opts       = self.opts
    local delimiter  = opts.delimiter
    local quote_char = opts.quote_char
    local has_header = opts.has_header

    local rows  = {}  --> string[][]
    local row   = {}  --> string[]
    local chars = {}  --> string[]
    local in_quotes = false  -- 是否处于引号包裹状态
    local i, len = 1, #csv_str

    while i <= len do
        local c = csv_str:sub(i, i)

        if c == quote_char then
            -- 处理引号：检查是否是转义（连续两个引号）
            local next_c = csv_str:sub(i + 1, i + 1)
            if next_c == quote_char then
                -- 转义引号：添加一个引号到当前字段
                _insert(chars, quote_char)
                i = i + 2  -- 跳过下一个引号
            else
                -- 切换引号状态（进入/退出）
                in_quotes = not in_quotes
                i = i + 1
            end

        elseif c == delimiter then
            -- 处理分隔符：仅在非引号内时作为字段分隔
            if not in_quotes then
                _insert(row, _concat(chars))
                _clear(chars)
            else
                _insert(chars, c)
            end
            i = i + 1

        elseif c == '\n' or c == '\r' then
            -- 处理换行：支持 \n 或 \r\n
            local is_crlf = (c == '\r' and csv_str:sub(i + 1, i + 1) == '\n')
            if is_crlf then
                i = i + 1  -- 跳过 \n（处理 \r\n）
            end

            if not in_quotes then
                -- 行结束：保存当前行
                _insert(row, _concat(chars))
                _clear(chars)
                _insert(rows, row)
                row = _newt(#row, 0)
            else
                _insert(chars, '\n')  -- 引号内换行保留
            end
            i = i + 1

        else
            -- 普通字符直接添加
            _insert(chars, c)
            i = i + 1
        end
    end

    -- 处理最后一行（无换行符结束的情况）
    if #chars > 0 or #row > 0 then
        _insert(row, _concat(chars))
        _insert(rows, row)
    end

    -- 若有表头，转换为键值对格式
    if has_header and #rows > 0 then
        local cols = _remove(rows, 1)
        local objs = _newt(#rows, 0)

        for _, r in ipairs(rows) do
            local obj = _newt(0, #cols)
            for j, val in ipairs(r) do
                local key = cols[j] or ("f_" .. j)
                obj[key] = val
            end
            _insert(objs, obj)
        end

        return objs
    end

    return rows

end

-- 生成 CSV（数组 → 字符串）
function _M:generate(data)
-- @data    : (string | number | boolean)[][]
-- @return  : string

    local opts      = self.opts
    local line_end  = opts.line_end
    local delimiter = opts.delimiter

    local lines = {}
    for _, row in ipairs(data) do
        local escaped = {}
        for _, field in ipairs(row) do
            _insert(escaped, escape_field(field, opts))
        end
        _insert(lines, _concat(escaped, delimiter))
    end

    return _concat(lines, line_end)

end

-- 测试
_M._TESTING = function()

    local data = {
        { "name", "age", "city" },
        { "Alice", 30, "New York" },
        { "Bob", 25, "Los Angeles" },
        { 'Charlie', 28, 'He said "Hello, World!"' },
    }

    local csv = _M.new { has_header = true}

    local csv_str = csv:generate(data)
    ngx.say(csv_str)

    local csv_lines = csv:parse(csv_str)
    return csv_lines

end

return _M
