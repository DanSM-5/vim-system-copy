if exists('g:loaded_system_copy') || v:version < 700
  finish
endif
let g:loaded_system_copy = 1

if !exists("g:system_copy_silent")
  let g:system_copy_silent = 0
endif
if !exists("g:system_copy_use_windows_clipboard")
  let g:system_copy_use_windows_clipboard = 0
endif

xnoremap <silent> <Plug>SystemCopy :<C-U>call systemcopy#system_copy(visualmode(),visualmode() ==# 'V' ? 1 : 0)<CR>
nnoremap <silent> <Plug>SystemCopy :<C-U>set opfunc=systemcopy#system_copy<CR>g@
nnoremap <silent> <Plug>SystemCopyLine :<C-U>set opfunc=systemcopy#system_copy<Bar>exe 'norm! 'v:count1.'g@_'<CR>
xnoremap <silent> <Plug>SystemPaste :<C-U>call systemcopy#system_paste(visualmode(),visualmode() ==# 'V' ? 1 : 0)<CR>
nnoremap <silent> <Plug>SystemPaste :<C-U>set opfunc=systemcopy#system_paste<CR>g@
nnoremap <silent> <Plug>SystemPasteLine :<C-U>set opfunc=systemcopy#system_paste_line<CR>g@_

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

