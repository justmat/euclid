--
--
-- er thing
--
--

for i = 1, 4 do arc_res(i, 15) end

----------
-- edit these tables to change the default notes.
-- uses midi note numbers.
notes = {
  {5},  -- ring 1
  {7},  -- ring 2
  {13},  -- ring 3
  {0, 4, 7, 11}   -- ring 4
}

octaves = {0, 12, 24, 36, 48, 60, 72}
octave = 5
----------

steps = {16, 16, 16, 32}
fills = {4, 2, 8, 7}
rotations = {0, 4, 2, 0}
divisions = {1, 2, 3, 4}
note_indexes = {1, 1, 1, 1}
note_add_indexes = {1, 1, 1, 1}
pos = {1, 1, 1, 1}
playing = {false, false, false, false}
piano_roll = {0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0}
alt = false
mode = 1
t = 1
time_ms = 100
channel_mode = 1


function set_note(ring, index, note, add)
  add = add or false
  if add then
    if notes[ring] < 64 then
      table.insert(notes[ring], note)
    end
  else
    notes[ring][index] = note
  end
end


function all_notes_off()
  for i = 0, 127 do
    midi_note_off(i, 0, 1)
  end
end


function er(k, n, w)
  -- taken from norns er.lua util
	-- k = steps
	-- n = fill
  -- w = offset/rotation
  w = w or 0
  -- results array, intially all false
  local r = {}
  for i=1,n do r[i] = false end

  if k<1 then return r end

  -- using the "bucket method"
  -- for each step in the output, add K to the bucket.
  -- if the bucket overflows, this step contains a pulse.
  local b = n
  for i=1,n do
    if b >= n then
      b = b - n
      local j = i + w
      while (j > n) do j = j - n end
      while (j < 1) do j = j + n end
      r[j] = true
    end
    b = b + k
  end
  return r
end

-- build initial sequences
seqs = {}
for i = 1, 4 do
  seqs[i] = er(fills[i], steps[i], rotations[i])
end


function arc(n, d)
  if alt and mode <= 5 then
    if d > 0 then
      playing[n] = true
    else
      playing[n] = false
      --all_notes_off()
    end
  else
    if mode == 1 then
      fills[n] = clamp(fills[n] + d, 1, 64)
    elseif mode == 2 then
      steps[n] = clamp(steps[n] + d, 1, 64)
    elseif mode == 3 then
      rotations[n] = wrap(rotations[n] + d, 1, 64)
    elseif mode == 4 then
      divisions[n] = clamp(divisions[n] + d, 1, 13)
    elseif mode == 5 then
      if n == 1 then
        time_ms = clamp(time_ms + d, 25, 500)
        metro_set(m, time_ms)
      elseif n == 2 then
        channel_mode = clamp(channel_mode + d, 1, 2)
      elseif n == 4 then
        octave = clamp(octave + d, 1, 7)
      end
    elseif mode == 6 then
      if alt then
        note_add_indexes[n] = clamp(note_add_indexes[n] + d, 1, 24)
        set_note(n, note_indexes[n], note_add_indexes[n] - 1, false)
      else
        note_indexes[n] = clamp(note_indexes[n] + d, 0, #notes[n] + 1)
        if note_indexes[n] == 0 then
          -- remove last note
          if #notes[n] > 1 then
            table.remove(notes[n], #notes[n])
          elseif #notes[n] < 1 then
            notes[n] = {0}
            note_indexes[n] = 1
          end
        elseif note_indexes[n] == (#notes[n] + 1) then
          -- add notes
          set_note(n, note_indexes[n] - 1, 0, true)
        end
        note_add_indexes[n] = notes[n][note_indexes[n]]
      end
    end
  end
  seqs[n] = er(fills[n], steps[n], rotations[n])
  arc_redraw()
end


function arc_key(z)
  if z == 1 then
    km = metro.new(key_timer,250,1)
  elseif km then
    -- short key press
    metro.stop(km)
    mode = wrap(mode + 1, 1, 6)
  else
    alt = false
  end
end


function key_timer()
  -- long key press
  metro.stop(km)
  km = nil
  alt = true
end


function arc_redraw()
  -- clear rings
  for i = 1, 4 do arc_led_all(i, 0) end
  -- draw shit -----------
  if mode == 1 or mode == 3 then
    -- sequences ---------
    for i = 1, 4 do
      for n = 1, steps[i] do
        arc_led(i, n, seqs[i][n] == true and 4 or 0)
      end
      if mode == 3 then
        arc_led(i, 1, 15)
        arc_led(i, steps[i], 15)
      end
    end
  elseif mode == 2 then
    -- steps -------------
    for i = 1, 4 do
      for n = 1, steps[i] do
        arc_led(i, n, seqs[i][n] == true and 12 or 2)
      end
    end
  elseif mode == 4 then
    -- clock divisions ---
    for i = 1, 4 do
      for n = 1, divisions[i] do
        arc_led(i, n, 4)
      end
    end
  elseif mode == 5 then
    -- speed
    local x = math.floor(linlin(25, 500, 1, 64, time_ms))
    for i = 1, x do
      arc_led(1, i, 4)
    end
    -- midi channel mode --
    for i = 1, 4 do
      if channel_mode == 1 then
        arc_led(2, i, 4)
      elseif channel_mode == 2 then
        arc_led(2, i + i, 4)
      end
    end
    -- octave offset
    for i = 1, octave do
      arc_led(4, i, 4)
    end
  elseif mode == 6 then
    -- add and remove notes from sequences
    if alt then
      for i = 1, 4 do
        for n = 1, #piano_roll do
          arc_led(i, n, piano_roll[n] == 1 and 6 or 2)
          arc_led(i, note_add_indexes[i], 15)
        end
      end
    else
      for i = 1, 4 do
        for n = 1, #notes[i] do
          arc_led(i, n, 2)
          arc_led(i, note_indexes[i], 15)
        end
        arc_led(i, 64, 8)
        arc_led(i, #notes[i] + 1, 8)
      end
    end
  end
  -- playhead position ----
  if mode < 5 then
    for i = 1, 4 do
      if mode <= 5 then
        arc_led(i, pos[i], 12)
      end
    end
  end
  arc_refresh()
end


function tick()
  for i = 1, 4 do
    if playing[i] and t % divisions[i] == 0 then
      if seqs[i][pos[i]] then
          midi_note_off(notes[i][note_indexes[i]] + octaves[octave], 0, channel_mode == 1 and 1 or i)
          note_indexes[i] = wrap(note_indexes[i] + 1, 1, #notes[i])
          midi_note_on(notes[i][note_indexes[i]] + octaves[octave], 127, channel_mode == 1 and 1 or i)
      else
        midi_note_off(notes[i][note_indexes[i]] + octaves[octave], 0, channel_mode == 1 and 1 or i)
      end
      pos[i] = wrap(pos[i] + 1, 1, steps[i])
    end
  end
  t = wrap(t + 1, 0, 64)
  arc_redraw()
end


m = metro.new(tick, time_ms)
