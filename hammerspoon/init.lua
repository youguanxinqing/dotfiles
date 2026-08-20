-- Hammerspoon 配置。目前只有一件事：给 bin/herdr-agent-attention 发通知。
--
-- hs.ipc 是 `hs -c` 能连上来的前提，没有它 CLI 会一直等到超时。
require("hs.ipc")

-- 用 hs.webview 而不是 hs.alert / hs.notify / hs.canvas：
--   hs.alert  位置只能居中或贴边，单一字体字重，没有图标位
--   hs.notify 走通知中心，长相归系统管，且固定右上角
--   hs.canvas 位置自由，但画不了背景模糊 —— 它只能填色，看不到身后的桌面
-- 透明 webview 里的 -webkit-backdrop-filter 会真的采样窗口背后的内容，
-- 这是这几条路里唯一能做到毛玻璃的。顺带滑入滑出交给 CSS，比 Lua 定时器干净。
local W, H = 560, 140

-- 停留 2.6s，加上两头的动画一共 3.2s（见 @keyframes drop 的时间轴）。
local LIFETIME = 3.45

local TEMPLATE = [[
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;height:100%;background:transparent;overflow:hidden}
body{display:flex;justify-content:{{justify}};align-items:flex-start;padding:8px 14px 0}
/* 扁而宽：横幅感，不是方块。min-width 让短文案也撑到同一宽度，
   连着弹几张时宽度不会忽大忽小。 */
.card{display:flex;gap:13px;align-items:stretch;box-sizing:border-box;
  min-width:340px;padding:10px 22px 11px 16px;border-radius:13px;
  background:rgba(31,56,42,0.90);
  -webkit-backdrop-filter:blur(28px) saturate(140%) brightness(0.55);
  border:1px solid rgba(163,190,140,0.28);
  box-shadow:0 10px 34px rgba(0,0,0,0.5);
  font-family:"PingFang SC",-apple-system,sans-serif;
  animation:drop 3.2s forwards}
.bar{width:3px;border-radius:2px;background:{{accent}};flex:none}
.col{flex:1;min-width:0}
/* 标题行左右分栏：标题贴左，agent 名贴右 */
.row{display:flex;align-items:baseline;gap:12px}
.t{font-weight:600;font-size:15px;line-height:1.3;color:#ECEFF4;letter-spacing:0.2px;flex:1}
.who{font-weight:500;font-size:11px;line-height:1.3;letter-spacing:0.6px;
  text-transform:uppercase;color:{{accent}};opacity:0.85;flex:none}
.b{font-weight:400;font-size:12.5px;line-height:1.3;color:rgba(216,222,233,0.72);margin-top:2px}
/* 起步快收尾慢地滑下来，停住，再快速收回去 —— 线性会像廉价网页 */
@keyframes drop{
  0%{transform:translateY(-160%);opacity:0;animation-timing-function:cubic-bezier(.16,1,.3,1)}
  9%{transform:translateY(0);opacity:1}
  90%{transform:translateY(0);opacity:1;animation-timing-function:cubic-bezier(.7,0,.84,0)}
  100%{transform:translateY(-160%);opacity:0}}
</style></head><body>
<div class="card"><div class="bar"></div><div class="col">
<div class="row"><div class="t">{{title}}</div><div class="who">{{agent}}</div></div>
<div class="b">{{body}}</div>
</div></div>
</body></html>
]]

local current -- 连按时先把上一张撤掉，不要叠成一摞

-- 文案来自 shell，直接拼进 HTML 之前得转义。
local function escape(text)
  return (tostring(text or ""):gsub("[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- 每个 agent 一个颜色，扫一眼就能分清是谁发的，不用读那行小字。
local ACCENT = {
  claude = "#A3BE8C", -- sage green
  codex = "#88C0D0", -- frost cyan
}
local ACCENT_FALLBACK = "#A3BE8C"

-- 供 CLI 调用：
--   hs -t 1 -q -c 'herdrToast({title=[[标题]], body=[[正文]], agent=[[claude]], align=[[right]]})'
-- align 省略即居中；"right" 靠右上角。agent 省略则不显示来源标签。
-- 返回 "ok" 让调用方能区分「弹出来了」和「函数没定义/配置没生效」。
function herdrToast(opts)
  if current then
    current:delete()
    current = nil
  end

  local toRight = opts.align == "right"
  local agent = opts.agent

  local html = TEMPLATE:gsub("{{title}}", function()
    return escape(opts.title)
  end):gsub("{{body}}", function()
    return escape(opts.body)
  end):gsub("{{agent}}", function()
    return escape(agent)
  end):gsub("{{accent}}", ACCENT[agent] or ACCENT_FALLBACK)
    :gsub("{{justify}}", toRight and "flex-end" or "center")

  local screen = hs.screen.mainScreen():frame()
  local x = toRight and (screen.x + screen.w - W) or (screen.x + (screen.w - W) / 2)
  local view = hs.webview.new({ x = x, y = screen.y, w = W, h = H })
  view:transparent(true)
  view:allowTextEntry(false)
  view:windowStyle({ "borderless", "nonactivating" })
  view:level(hs.canvas.windowLevels.overlay)
  view:html(html)
  view:show()

  current = view
  hs.timer.doAfter(LIFETIME, function()
    if current == view then
      current = nil
    end
    view:delete()
  end)

  return "ok"
end
