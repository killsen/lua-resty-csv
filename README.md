# LUA-RESTY-CSV

## 功能

* 支持标准 CSV 解析 / 生成（引号包裹、转义、换行字段）
* 可自定义分隔符（逗号、制表符等）、引号字符、行结束符
* 解析时自动转换为带表头的键值对（可选）

## 示例

```lua

local CSV = require "resty.csv"

local csv = CSV.new {
    delimiter  = ',',    -- 字段分隔符（默认逗号）
    quote_char = '"',    -- 引号字符（默认双引号）
    line_end   = '\n',   -- 行结束符（默认 \n，Windows
    has_header = false,  -- 解析时是否包含表头（默认否）
}

local data = {
    { "name", "age", "city" },
    { "Alice", 30, "New York" },
    { "Bob", 25, "Los Angeles" },
    { 'Charlie', 28, 'He said "Hello, World!"' },
}

local csv_str = csv:generate(data)
ngx.say(csv_str)

local rows = csv:parse(csv_str)
for _, row in ipairs(rows) do
    ngx.say(require("cjson.safe").encode(row))
end

csv = CSV.new { has_header = true }
local objs = csv:parse(csv_str)
for _, obj in ipairs(objs) do
    ngx.say(require("cjson.safe").encode(obj))
end

```
