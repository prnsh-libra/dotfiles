--!nonstrict
-- GitHub desktop widget for Noctalia.
--
-- Lists open pull requests OR issues, newest first, fetched with the `gh` CLI.
-- Per-instance settings (see plugin.toml):
--   kind   = "prs" | "issues"
--   author = "everyone" | "me"
--   cap    = 1..50 maximum rows
--
-- Scope semantics:
--   "me"       -> --author=@me : only items you authored (anywhere).
--   "everyone" -> --owner=<each org + your account> : every open item in the
--                 orgs/accounts you belong to, by any author. Falls back to
--                 --involves=@me if the owner list can't be resolved.
-- Each row is clickable and opens the item on GitHub via xdg-open.

local REFRESH_MS = 300000 -- refetch every 5 minutes
local GH_TIMEOUT_MS = 30000
local MAX_CAP = 50

local items = nil        -- decoded array once a fetch succeeds; kept across refetches
local status = "loading" -- "loading" | "ok" | "error"
local errText = ""
local fetching = false
local owners = nil       -- cached { login, org1, org2, ... } for "everyone" scope
local pulsePhase = 0     -- seconds accumulator driving the refresh fade
local stale = false      -- true when showing last-known data, not a fresh fetch

-- Shell-quote a value for the string command form of runAsync.
local function q(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function readConfig()
  local kind = noctalia.getConfig("kind") or "prs"
  local author = noctalia.getConfig("author") or "everyone"
  local cap = tonumber(noctalia.getConfig("cap")) or MAX_CAP
  cap = math.floor(cap)
  if cap < 1 then cap = 1 end
  if cap > MAX_CAP then cap = MAX_CAP end
  return kind, author, cap
end

-- Persistent cache path for the resolved owner list (survives restarts and
-- transient GitHub API outages).
local function ownersCachePath()
  local dir = noctalia.pluginDataDir()
  if dir == nil then
    return nil
  end
  return dir .. "/owners.json"
end

-- Load a previously resolved owner list from disk so a GitHub API blip at
-- startup does not force the "everyone" scope into its my-only fallback.
local function loadOwnersCache()
  local p = ownersCachePath()
  if p == nil then
    return
  end
  local raw = noctalia.readFile(p)
  if raw then
    local decoded = noctalia.json.decode(raw)
    if type(decoded) == "table" and #decoded > 0 then
      owners = decoded
    end
  end
end

-- Persistent cache of the last successful result set, keyed by content + scope
-- so the two tiles never clash. Lets the widget show the last-known list
-- (marked stale) instead of an error screen after a reload during an outage.
local function resultsCachePath(kind, author)
  local dir = noctalia.pluginDataDir()
  if dir == nil then
    return nil
  end
  return dir .. "/results-" .. tostring(kind) .. "-" .. tostring(author) .. ".json"
end

local function saveResults(kind, author, list)
  local p = resultsCachePath(kind, author)
  if p then
    noctalia.writeFile(p, noctalia.json.encode(list))
  end
end

local function loadResults(kind, author)
  local p = resultsCachePath(kind, author)
  if p == nil then
    return nil
  end
  local raw = noctalia.readFile(p)
  if raw then
    local decoded = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      return decoded
    end
  end
  return nil
end

-- Resolve the owner set for "everyone" (your login + every org you belong to).
-- A successful, non-empty result is cached in memory and on disk. Failures and
-- empty results are NEVER cached, so the next fetch retries instead of getting
-- stuck in the my-only fallback (e.g. after a transient HTTP 503).
local function ensureOwners(cb)
  if owners ~= nil and #owners > 0 then
    cb(true)
    return
  end
  loadOwnersCache() -- try the on-disk cache before hitting the API
  if owners ~= nil and #owners > 0 then
    cb(true)
    return
  end
  local ok = noctalia.runAsync("gh api user --jq .login; gh api user/orgs --jq '.[].login'", function(result)
    if result.exitCode == 0 then
      local list = {}
      for line in (result.stdout or ""):gmatch("[^\r\n]+") do
        local o = noctalia.string.trim(line)
        if o ~= "" then
          table.insert(list, o)
        end
      end
      if #list > 0 then
        owners = list
        local p = ownersCachePath()
        if p then
          noctalia.writeFile(p, noctalia.json.encode(list))
        end
      end
    end
    cb(owners ~= nil and #owners > 0)
  end, GH_TIMEOUT_MS)
  if not ok then
    cb(false)
  end
end

local function buildCommand(kind, scope, cap)
  local sub = (kind == "issues") and "issues" or "prs"

  local scopeArgs
  if scope == "me" then
    scopeArgs = "--author=@me"
  elseif owners and #owners > 0 then
    local parts = {}
    for _, o in ipairs(owners) do
      table.insert(parts, "--owner=" .. q(o))
    end
    scopeArgs = table.concat(parts, " ")
  else
    scopeArgs = "--involves=@me" -- fallback when owner list is unavailable
  end

  -- jq contains no single quotes, so q() wraps it safely.
  local jq =
    '[.[] | {number, title, url, repo: .repository.nameWithOwner, author: .author.login, ago: (now - (.updatedAt|fromdateiso8601))}]'
  return "gh search "
    .. sub
    .. " --state=open "
    .. scopeArgs
    .. " --sort=updated --order=desc"
    .. " --limit="
    .. tostring(cap)
    .. " --json number,title,repository,author,updatedAt,url"
    .. " --jq "
    .. q(jq)
end

-- Compact "time since" from a seconds-ago number.
local function relTime(ago)
  local s = tonumber(ago)
  if s == nil or s < 0 then
    return ""
  end
  s = math.floor(s)
  if s < 60 then
    return s .. "s"
  end
  local m = math.floor(s / 60)
  if m < 60 then
    return m .. "m"
  end
  local h = math.floor(m / 60)
  if h < 24 then
    return h .. "h"
  end
  local d = math.floor(h / 24)
  if d < 14 then
    return d .. "d"
  end
  local w = math.floor(d / 7)
  if w < 9 then
    return w .. "w"
  end
  local mo = math.floor(d / 30)
  if mo < 12 then
    return mo .. "mo"
  end
  return math.floor(d / 365) .. "y"
end

local function buildHeader(kind, count)
  local title = (kind == "issues") and "Issues" or "Pull Requests"
  local glyph = (kind == "issues") and "info-circle" or "git-pull-request"
  return ui.row({ gap = 8, align = "center", onClick = "reloadWidget" }, {
    ui.glyph({ name = glyph, size = 18, color = "primary" }),
    ui.label({
      text = title,
      fontSize = 15,
      fontWeight = "bold",
      color = "on_surface",
      textAlign = "start",
      flexGrow = 1,
    }),
    ui.label({ text = tostring(count), fontSize = 15, fontWeight = "bold", color = "primary" }),
  })
end

local function buildRow(it)
  local url = tostring(it.url or "")
  local title = tostring(it.title or "(untitled)")
  local repo = tostring(it.repo or "")
  local num = "#" .. tostring(it.number or "?")
  local author = tostring(it.author or "")
  local age = relTime(it.ago)
  return ui.column({
    key = url,
    gap = 1,
    paddingV = 5,
    paddingH = 8,
    radius = 8,
    fill = "surface_variant/0.35",
    onClick = function()
      if url ~= "" then
        noctalia.runAsync("xdg-open " .. q(url))
      end
    end,
  }, {
    ui.label({
      text = title,
      fontSize = 12,
      fontWeight = "medium",
      color = "on_surface",
      textAlign = "start",
      maxLines = 1,
      maxWidth = 384,
    }),
    ui.row({ gap = 6, align = "center" }, {
      ui.label({
        text = repo .. " " .. num,
        fontSize = 10,
        color = "on_surface_variant",
        textAlign = "start",
        maxLines = 1,
        flexGrow = 1,
      }),
      ui.label({ text = author, fontSize = 10, color = "on_surface_variant" }),
      ui.label({ text = age, fontSize = 10, fontWeight = "bold", color = "primary" }),
    }),
  })
end

-- Opacity pulse used while a fetch is in flight (fade the content in and out).
local function pulseOpacity()
  local period = 1.1
  local t = 0.5 + 0.5 * math.sin(2 * math.pi * pulsePhase / period)
  return 0.65 + 0.35 * t
end

local function buildTree()
  local kind = readConfig()
  local listHeight = 440
  local list = items or {}
  local count = #list
  local children = {}
  table.insert(children, buildHeader(kind, count))
  table.insert(children, ui.separator({ spacing = 4 }))

  if items == nil and status == "loading" then
    table.insert(
      children,
      ui.row({ gap = 6, align = "center", paddingV = 8 }, {
        ui.glyph({ name = "loader-2", size = 14, color = "on_surface_variant" }),
        ui.label({ text = "Loading…", fontSize = 12, color = "on_surface_variant", textAlign = "start" }),
      })
    )
  elseif items == nil and status == "error" then
    table.insert(
      children,
      ui.column({ gap = 4, paddingV = 6 }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({ name = "alert-triangle", size = 14, color = "error" }),
          ui.label({ text = "Couldn't load", fontSize = 12, fontWeight = "bold", color = "error", textAlign = "start" }),
        }),
        ui.label({ text = errText, fontSize = 10, color = "on_surface_variant", textAlign = "start", maxLines = 4, maxWidth = 380 }),
      })
    )
  elseif count == 0 then
    table.insert(
      children,
      ui.row({ gap = 6, align = "center", paddingV = 8 }, {
        ui.glyph({ name = "check", size = 14, color = "primary" }),
        ui.label({ text = "Nothing open", fontSize = 12, color = "on_surface_variant", textAlign = "start" }),
      })
    )
  else
    local rows = {}
    for _, it in ipairs(list) do
      table.insert(rows, buildRow(it))
    end
    table.insert(children, ui.scroll({ gap = 4, flexGrow = 1 }, rows))
  end

  return ui.column({
    gap = 6,
    padding = 8,
    width = 432,
    height = listHeight,
    align = "stretch",
    opacity = fetching and pulseOpacity() or 1.0,
  }, children)
end

local function render()
  desktopWidget.render(buildTree())
end

local function runSearch(cmd, kind, author)
  local started = noctalia.runAsync(cmd, function(result)
    fetching = false
    if result.timedOut then
      status = "error"
      stale = items ~= nil
      errText = "gh timed out"
    elseif result.exitCode ~= 0 then
      status = "error"
      stale = items ~= nil
      local msg = noctalia.string.trim(result.stderr or "")
      msg = msg:match("^[^\r\n]+") or ""
      if msg == "" then
        msg = "gh exited with code " .. tostring(result.exitCode)
      elseif msg:find("No server is currently available", 1, true) or msg:find("503", 1, true) then
        msg = "GitHub is temporarily unavailable"
      elseif #msg > 80 then
        msg = msg:sub(1, 80) .. "…"
      end
      errText = msg
    else
      local decoded, err = noctalia.json.decode(result.stdout)
      if type(decoded) == "table" then
        items = decoded
        status = "ok"
        stale = false
        errText = ""
        saveResults(kind, author, decoded)
      else
        status = "error"
        stale = items ~= nil
        errText = "Failed to parse gh output: " .. tostring(err)
      end
    end
    render()
  end, GH_TIMEOUT_MS)

  if not started then
    fetching = false
    status = "error"
    stale = items ~= nil
    errText = "Failed to launch gh"
    render()
  end
end

local function fetch()
  if fetching then
    return
  end

  local kind, author, cap = readConfig()

  -- Seed from the on-disk cache so a reload during an outage shows the
  -- last-known list immediately instead of an error screen.
  if items == nil then
    local cached = loadResults(kind, author)
    if cached ~= nil then
      items = cached
      status = "ok"
      stale = true
      render()
    end
  end

  if not noctalia.commandExists("gh") then
    status = "error"
    stale = items ~= nil
    errText = "The `gh` CLI is not installed or not on PATH."
    render()
    return
  end

  fetching = true
  pulsePhase = 0
  desktopWidget.setNeedsFrameTick(true)
  if author == "me" then
    runSearch(buildCommand(kind, "me", cap), kind, author)
  else
    ensureOwners(function(ok)
      if ok then
        runSearch(buildCommand(kind, "everyone", cap), kind, author)
      else
        -- Owners unavailable (e.g. GitHub API down): do NOT run the my-only
        -- fallback or cache it as everyone. Keep last-known data, retry later.
        fetching = false
        desktopWidget.setNeedsFrameTick(false)
        status = "error"
        stale = items ~= nil
        errText = "couldn't resolve your orgs (GitHub API); retrying"
        render()
      end
    end)
  end
end

-- Named handler for the header's onClick: force an immediate refetch.
function reloadWidget()
  fetch()
end

-- Warm the owner list from disk at load so "everyone" survives an API outage.
loadOwnersCache()

function update()
  noctalia.setUpdateInterval(REFRESH_MS)
  render()
  fetch()
end

-- Drives the refresh fade: while fetching, advance the pulse and re-render each
-- frame; once the fetch finishes, settle at full opacity and stop ticking.
function onFrameTick(deltaMs)
  if fetching then
    pulsePhase = pulsePhase + (tonumber(deltaMs) or 16) / 1000
    render()
  else
    desktopWidget.setNeedsFrameTick(false)
    render()
  end
end
