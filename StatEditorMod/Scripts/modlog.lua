local Notifications = require("notifications")

local ModLog = {}

local BatchDepth = 0
local BatchLines = {}

local HUD_SINGLE_MAX = 220
local HUD_BLOCK_MAX = 1000
local HUD_BATCH_LINE_MAX = 10

local function TrimHudLine(Message)
    local Line = Message or ""
    Line = string.gsub(Line, "\r", "")
    Line = string.gsub(Line, "[\n]+", " ")
    Line = string.gsub(Line, "^%s+", "")
    Line = string.gsub(Line, "%s+$", "")
    return Line
end

local function TrimHudBlock(Message)
    local Block = Message or ""
    if #Block > HUD_BLOCK_MAX then
        Block = string.sub(Block, 1, HUD_BLOCK_MAX - 3) .. "..."
    end
    return Block
end

local function PushHudLine(Line)
    if Line == "" then
        return
    end

    if BatchDepth > 0 then
        table.insert(BatchLines, Line)
        return
    end

    local Single = Line
    if #Single > HUD_SINGLE_MAX then
        Single = string.sub(Single, 1, HUD_SINGLE_MAX - 3) .. "..."
    end
    Notifications.TryShow(Single)
end

function ModLog.BeginBatch()
    BatchDepth = BatchDepth + 1
    if BatchDepth == 1 then
        BatchLines = {}
    end
end

function ModLog.EndBatch()
    if BatchDepth <= 0 then
        return
    end

    BatchDepth = BatchDepth - 1
    if BatchDepth == 0 and #BatchLines > 0 then
        local Block = table.concat(BatchLines, "\n")
        if #BatchLines > HUD_BATCH_LINE_MAX or #Block > HUD_BLOCK_MAX then
            Notifications.TryShow(string.format(
                "[StatEditorMod] %d lines -> UE4SS.log",
                #BatchLines
            ))
        else
            Notifications.TryShow(TrimHudBlock(Block))
        end
        BatchLines = {}
    end
end

function ModLog.Write(Message)
    local Text = Message or ""
    if not string.match(Text, "\n$") then
        Text = Text .. "\n"
    end
    print(Text)

    PushHudLine(TrimHudLine(Text))
end

return ModLog
