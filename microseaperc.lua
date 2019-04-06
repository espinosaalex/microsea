-- earthsea 1 microtonal octave
--
-- subtractive polysynth
-- controlled by midi or grid
--
-- grid pattern player:
-- 1 1 record toggle
-- 1 2 play toggle
-- 1 8 transpose mode

local tab = require 'tabutil'
local pattern_time = require 'pattern_time'
local cs = require 'controlspec'

local g = grid.connect()

local mode_transpose = 0
local root = { x=5, y=5 }
local trans = { x=5, y=5 }
local lit = {}
local sa = { x=7, y=4 }
sa.id = sa.x*8 + sa.y



local MAX_NUM_VOICES = 16

engine.name = 'PolyPerc'

local base = 128

local function octave_reduce(ratio)
  local oct_reduced = ratio.x * ratio.y
  while (oct_reduced < 1) 
  do
    oct_reduced = oct_reduced * 2
  end
  while (oct_reduced > 2) 
  do
    oct_reduced = oct_reduced / 2
  end
  return oct_reduced
end

local function getHz(e)
  local ratio = {}
  -- print("e.x".. e.x .. " e.y" .. e.y)
  ratio.x = (3/2) ^ (e.x - sa.x)
  if ratio.x == 0 then ratio.x = 1 end
  ratio.y = (5/4) ^ (sa.y - e.y)
  if ratio.y == 0 then ratio.y = 1 end
  -- print(base*octave_reduce(ratio))
  return base * octave_reduce(ratio)
end


  
-- current count of active voices
local nvoices = 0

function init()
  pat = pattern_time.new()
  pat.process = grid_note_trans

  cs.AMP = cs.new(0,1,'lin',0,0.5,'')
  params:add_control("amp", "amp", cs.AMP)
  params:set_action("amp",
  function(x) engine.amp(x) end)

  cs.PW = cs.new(0,100,'lin',0,80,'%')
  params:add_control("pw", "pw", cs.PW)
  params:set_action("pw",
  function(x) engine.pw(x/100) end)

  cs.REL = cs.new(0.1,3.2,'lin',0,0.2,'s')
  params:add_control("release", "release", cs.REL)
  params:set_action("release",
  function(x) engine.release(x) end)

  cs.CUT = cs.new(50,5000,'exp',0,555,'hz')
  params:add_control("cutoff", "cutoff", cs.CUT)
  params:set_action("cutoff",
  function(x) engine.cutoff(x) end)

  cs.GAIN = cs.new(0,4,'lin',0,1,'')
  params:add_control("gain", "gain", cs.GAIN)
  params:set_action("gain",
  function(x) engine.gain(x) end)


  engine.amp(0.5)


  params:bang()
  
  lit[sa.id] = {}
  lit[sa.id].x = sa.x
  lit[sa.id].y = sa.y

  if g then gridredraw() end

end

function g.key(x, y, z)
  if x == 1 then
    if z == 1 then
      if y == 1 and pat.rec == 0 then
        mode_transpose = 0
        trans.x = 5
        trans.y = 5
        pat:stop()
        -- engine.stopAll()
        pat:clear()
        pat:rec_start()
      elseif y == 1 and pat.rec == 1 then
        pat:rec_stop()
        if pat.count > 0 then
          root.x = pat.event[1].x
          root.y = pat.event[1].y
          trans.x = root.x
          trans.y = root.y
          pat:start()
        end
      elseif y == 2 and pat.play == 0 and pat.count > 0 then
        if pat.rec == 1 then
          pat:rec_stop()
        end
        pat:start()
      elseif y == 2 and pat.play == 1 then
        pat:stop()
        -- engine.stopAll()
        nvoices = 0
        lit = {}
      elseif y == 8 then
        mode_transpose = 1 - mode_transpose
      end
    end
  else
    if mode_transpose == 0 then
      local e = {}
      e.id = x*8 + y
      e.x = x
      e.y = y
      e.state = z
      pat:watch(e)
      grid_note(e)
    else
      trans.x = x
      trans.y = y
    end
  end
  gridredraw()
end


function grid_note(e)
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      engine.hz(getHz(e))
      lit[e.id] = {}
      lit[e.id].x = e.x
      lit[e.id].y = e.y
      nvoices = nvoices + 1
    end
  else
    if lit[e.id] ~= nil then
      -- engine.stop(e.id)
      lit[e.id] = nil
      nvoices = nvoices - 1
    end
  end
  gridredraw()
end

function grid_note_trans(e)
  local note = {}
  note.x = e.x + trans.x - root.x
  note.y = e.y + trans.y - root.y
  note.id = e.x*8 + e.y
  
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      engine.hz(getHz(note))
      lit[e.id] = {}
      lit[e.id].x = e.x + trans.x - root.x
      lit[e.id].y = e.y + trans.y - root.y
      nvoices = nvoices + 1
    end
  else
    -- engine.stop(e.id)
    lit[e.id] = nil
    nvoices = nvoices - 1
  end
  gridredraw()
end

function gridredraw()
  g:all(0)
  g:led(1,1,2 + pat.rec * 10)
  g:led(1,2,2 + pat.play * 10)
  g:led(1,8,2 + mode_transpose * 10)

  if mode_transpose == 1 then g:led(trans.x, trans.y, 4) end
  for i,e in pairs(lit) do
    g:led(e.x, e.y,15)
  end

  g:refresh()
end



function enc(n,delta)
  if n == 1 then
    mix:delta("output", delta)
  end
end

function key(n,z)
end

function cleanup()
  pat:stop()
  pat = nil
end
