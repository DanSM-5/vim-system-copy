if exists('g:loaded_system_copy') || v:version < 700
  finish
endif
let g:loaded_system_copy = 1

if !exists("g:system_copy_silent")
  let g:system_copy_silent = 0
endif
if !exists("g:wsl_use_windows_clipboard")
  let g:wsl_use_windows_clipboard = 0
endif

let s:blockwise = 'blockwise visual'
let s:visual = 'visual'
let s:motion = 'motion'
let s:linewise = 'linewise'
let s:mac = 'mac'
let s:windows = 'windows'
let s:wsl1 = 'wsl1'
let s:wsl2 = 'wsl2'
let s:linux = 'linux'
" The class'[[:cntrl:]]' can be used too but it will remove new lines '\n'
let s:pwshrgx = '[\xFF\xFE\x01\r]' " <ff>,<fe>,^A,^M if powershell is set as shell

function! s:system_copy(type, ...) abort
  let mode = <SID>resolve_mode(a:type, a:0)
  let unnamed = @@
  if mode == s:linewise
    let lines = { 'start': line("'["), 'end': line("']") }
    silent exe lines.start . "," . lines.end . "y"
  elseif mode == s:visual || mode == s:blockwise
    silent exe "normal! `<" . a:type . "`>y"
  else
    silent exe "normal! `[v`]y"
  endif
  let os = <SID>currentOS()
  let command = s:CopyCommandForCurrentOS(os)
  silent let command_output = s:set_clipboard(os, command)
  if v:shell_error != 0
    " Fall back to call OSC52 copy
    if exists("g:system_copy_enable_osc52") && g:system_copy_enable_osc52 > 0 && exists('*YankOSC52')
      call YankOSC52(getreg('@'))
    else
      echoerr command_output
    endif
  else
    if g:system_copy_silent == 0
      echohl String | echon 'Copied: ' . command | echohl None
    endif
  endif
  let @@ = unnamed
endfunction

function! s:system_paste(type, ...) abort
  let os = <SID>currentOS()
  let command = <SID>PasteCommandForCurrentOS(os)
  silent let command_output = <SID>get_clipboard(os, command)
  if v:shell_error != 0
    echoerr command_output
  else
    let paste_content = command_output
    let mode = <SID>resolve_mode(a:type, a:0)
    let unnamed = @@
    silent exe "set paste"
    if mode == s:linewise
      let lines = { 'start': line("'["), 'end': line("']") }
      silent exe lines.start . "," . lines.end . "d"
      silent exe "normal! O" . paste_content
    elseif mode == s:visual || mode == s:blockwise
      silent exe "normal! `<" . a:type . "`>c" . paste_content
    else
      silent exe "normal! `[v`]c" . paste_content
    endif
    silent exe "set nopaste"
    if g:system_copy_silent == 0
      echohl String | echon 'Pasted: ' . command | echohl None
    endif
    let @@ = unnamed
  endif
endfunction

function! s:system_paste_line() abort
  let os = <SID>currentOS()
  let command = <SID>PasteCommandForCurrentOS(os)
  silent let command_output = <SID>get_clipboard(os, command)
  if v:shell_error != 0
    echoerr command_output
  else
    let paste_content = command_output
    put =paste_content
    if g:system_copy_silent == 0
      echohl String | echon 'Pasted: ' . command | echohl None
    endif
  endif
endfunction

function! s:set_clipboard(os, comm)
  if a:os == s:windows
    " If using powershell the command will fail due to '<' input redirection
    " Termporaly set shell to cmd to process command
    let tmpshellname=&shell
    let tmpshellcmdflag=&shellcmdflag
    try
      set shell=cmd
      set shellcmdflag=/c
      silent let command_output = system(a:comm, getreg('@'))
    finally
      exe 'set shell='.fnameescape(tmpshellname)
      exe 'set shellcmdflag='.fnameescape(tmpshellcmdflag)
    endtry
  else
    silent let command_output = system(a:comm, getreg('@'))
  endif

  return command_output
endfunction

function! s:get_clipboard(os, comm)
  if a:os == s:windows
    " If shell is powershell, it will append <ff><fe> and ctrl keys in the text
    " Use regex to remove ctrl keys and utf16 BOM
    " return substitute(system(a:comm), s:pwshrgx, '', 'g')
    " Use cmd temporaly to avoid regex on long strings
    let tmpshellname=&shell
    let tmpshellcmdflag=&shellcmdflag
    try
      set shell=cmd
      set shellcmdflag=/c
      silent let command_output = system(a:comm)
    finally
      exe 'set shell='.fnameescape(tmpshellname)
      exe 'set shellcmdflag='.fnameescape(tmpshellcmdflag)
    endtry
    return command_output
    " for wsl clean carriage return in case using windows clipboard commands
  elseif a:os == s:wsl1 || a:os == s:wsl2
    return substitute(system(a:comm), '\r', '', 'g')
  else
    return system(a:comm)
  endif
endfunction

function! s:resolve_mode(type, arg)
  let visual_mode = a:arg != 0
  if visual_mode
    return (a:type == '') ?  s:blockwise : s:visual
  elseif a:type == 'line'
    return s:linewise
  else
    return s:motion
  endif
endfunction

function! s:currentOS()
  let os = substitute(system('uname'), '[\xFF\xFE\x01\r\n]', '', '')
  let known_os = 'unknown'
  if has('gui_mac') || os ==? 'Darwin'
    let known_os = s:mac
  elseif has('win32') || has('gui_win32') || has('win32unix') || os =~? 'cygwin' || os =~? 'MINGW' || os =~? 'MSYS'
    let known_os = s:windows
  elseif os ==? 'Linux'
    let extended_os = system('uname -a')
    if extended_os =~? 'WSL2'
      let known_os = s:wsl2
    elseif extended_os =~? 'Microsoft'
      let known_os = s:wsl1
    else
      let known_os = s:linux
    endif
  else
    exe "normal \<Esc>"
    throw "unknown OS: " . os
  endif
  return known_os
endfunction

function! s:CopyCommandForCurrentOS(os)
  if exists('g:system_copy#copy_command')
    return g:system_copy#copy_command
  endif
  if a:os == s:mac
    return 'pbcopy'
  elseif a:os == s:windows || a:os == s:wsl1 || g:wsl_use_windows_clipboard
    return 'clip'
  elseif a:os == s:linux || a:os == s:wsl2
    if !empty($WAYLAND_DISPLAY)
      return 'wl-copy'
    else
      if executable('xsel')
        return 'xsel --clipboard --input'
      else
        return 'xclip -i -selection clipboard'
      endif
    endif
  endif
endfunction

function! s:PasteCommandForCurrentOS(os)
  if exists('g:system_copy#paste_command')
    return g:system_copy#paste_command
  endif
  if a:os == s:mac
    return 'pbpaste'
  elseif a:os == s:windows || a:os == s:wsl1 || g:wsl_use_windows_clipboard
    if executable('pbpaste.exe')
      return 'pbpaste'
    elseif executable('win32yank')
      return 'win32yank -i --crlf'
    else
      return 'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-Clipboard"'
    endif
  elseif a:os == s:linux || a:os == a:wsl2
    if !empty($WAYLAND_DISPLAY)
      return 'wl-paste -n'
    else
      if executable('xsel')
        return 'xsel --clipboard --output'
      else
        return 'xclip -o -selection clipboard'
      endif
    endif
  endif
endfunction

xnoremap <silent> <Plug>SystemCopy :<C-U>call <SID>system_copy(visualmode(),visualmode() ==# 'V' ? 1 : 0)<CR>
nnoremap <silent> <Plug>SystemCopy :<C-U>set opfunc=<SID>system_copy<CR>g@
nnoremap <silent> <Plug>SystemCopyLine :<C-U>set opfunc=<SID>system_copy<Bar>exe 'norm! 'v:count1.'g@_'<CR>
xnoremap <silent> <Plug>SystemPaste :<C-U>call <SID>system_paste(visualmode(),visualmode() ==# 'V' ? 1 : 0)<CR>
nnoremap <silent> <Plug>SystemPaste :<C-U>set opfunc=<SID>system_paste<CR>g@
nnoremap <silent> <Plug>SystemPasteLine :<C-U>call <SID>system_paste_line()<CR>

if !hasmapto('<Plug>SystemCopy', 'n') || maparg('cp', 'n') ==# ''
  nmap cp <Plug>SystemCopy
endif

if !hasmapto('<Plug>SystemCopy', 'v') || maparg('cp', 'v') ==# ''
  xmap cp <Plug>SystemCopy
endif

if !hasmapto('<Plug>SystemCopyLine', 'n') || maparg('cP', 'n') ==# ''
  nmap cP <Plug>SystemCopyLine
endif

if !hasmapto('<Plug>SystemPaste', 'n') || maparg('cv', 'n') ==# ''
  nmap cv <Plug>SystemPaste
endif

if !hasmapto('<Plug>SystemPaste', 'v') || maparg('cv', 'v') ==# ''
  xmap cv <Plug>SystemPaste
endif

if !hasmapto('<Plug>SystemPasteLine', 'n') || maparg('cV', 'n') ==# ''
  nmap cV <Plug>SystemPasteLine
endif
" vim:ts=2:sw=2:sts=2
