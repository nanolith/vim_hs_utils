vim9script

final PLUGIN_ROOT = fnamemodify(expand('<script>'), ':p:h:h')
final BIN_PATH    = PLUGIN_ROOT .. '/bin/v9_hs_uuid2c'

def EnsureBinary(): bool
  if executable(BIN_PATH)
    return true
  endif

  # Binary is missing -> attempt to build it automatically
  echomsg "Building Haskell binary for v9_hs_uuid2c..."
  
  # Run make inside the plugin directory
  var output = systemlist($"make -C '{PLUGIN_ROOT}'")

  if v:shell_error != 0
    echoerr $"Failed to build Haskell binary:\n{join(output, "\n")}"
    return false
  endif

  echomsg "Build successful!"
  return true
enddef

export def GenerateUUID(count: number, style: string = 'c_array')
  # Automatically compile if missing
  if !EnsureBinary()
    return
  endif

  var job = job_start([BIN_PATH], {
    in_mode: 'json',
    out_mode: 'json'
  })

  var chan = job_getchannel(job)
  if ch_status(chan) != "open"
    echoerr "Failed to connect to uuidgen_rcpr_uuid channel."
    return
  endif

  var start_line = line('.')
  var end_line = start_line + count - 1

  # Iterate backwards so added lines don't offset subsequent line indices
  for lnum in range(end_line, start_line, -1)
    var line_text = trim(getline(lnum))
    if empty(line_text)
      continue
    endif

    var req = {
      cmd: "variableToUUIDInit",
      line: line_text,
      style: style
    }

    var resp = ch_evalexpr(chan, req, {timeout: 2000})

    if has_key(resp, 'lines') && !empty(resp.lines)
      setline(lnum, resp.lines[0])
      if len(resp.lines) > 1
        append(lnum, resp.lines[1 :])
      endif
    elseif has_key(resp, 'message')
      echoerr $'Haskell error on line {lnum}: {resp.message}'
    endif
  endfor

  ch_evalexpr(chan, {cmd: "shutdown"}, {timeout: 1000})
  job_stop(job)
enddef
