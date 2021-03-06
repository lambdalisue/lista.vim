let s:HASH = sha256(expand('<sfile>:p'))


function! lista#filter#start(context) abort
  let bufnr = bufnr('%')
  let bufhidden = &bufhidden
  let &bufhidden = 'hide'
  execute printf(
        \ 'keepalt keepjumps edit %s',
        \ fnameescape('lista://' . expand('%:p')),
        \)
  execute printf('cnoremap <silent><buffer> <Plug>(lista-accept) %s<CR>', s:HASH)
  cnoremap <silent><buffer><expr> <Plug>(lista-prev-line) <SID>move_to_prev_line()
  cnoremap <silent><buffer><expr> <Plug>(lista-next-line) <SID>move_to_next_line()
  cnoremap <silent><buffer><expr> <Plug>(lista-prev-matcher) <SID>switch_to_prev_matcher()
  cnoremap <silent><buffer><expr> <Plug>(lista-next-matcher) <SID>switch_to_next_matcher()
  cnoremap <silent><buffer><expr> <Plug>(lista-switch-ignorecase) <SID>switch_ignorecase()
  setlocal buftype=nofile bufhidden=wipe undolevels=-1
  setlocal noswapfile nobuflisted
  setlocal filetype=lista

  let b:context = a:context
  call s:update()
  try
    call timer_start(
        \ b:context.interval,
        \ funcref('s:consumer'),
        \)
    return (input(a:context.prompt, a:context.query)[-64:] ==# s:HASH)
  finally
    execute 'keepalt keepjumps buffer' bufnr
    let &bufhidden = bufhidden
    redraw
  endtry
endfunction

function! s:consumer(...) abort
  if getcmdtype() !=# '@'
    return
  elseif getcmdline() !=# b:context.query
    call s:update()
  endif
  call timer_start(
       \ b:context.interval,
       \ funcref('s:consumer'),
       \)
endfunction

function! s:update(...) abort
  let query = getcmdline()
  let ignorecase = b:context.ignorecase
  let matcher = b:context.matchers[b:context.matcher]
  let content = b:context.content
  let pattern = matcher.pattern(query, ignorecase)
  let indices = matcher.filter(content, query, ignorecase)
  let b:context.query = query
  let b:context.indices = indices
  let b:context.cursor = max([min([b:context.cursor, len(indices)]), 1])
  call s:update_statusline(b:context)
  redrawstatus
  call s:update_content(content, indices, b:context.number)
  call s:update_hlsearch(pattern, ignorecase)
  call cursor(b:context.cursor, 1, 0)
  redraw
endfunction

function! s:update_content(content, indices, number) abort
  if empty(a:indices)
    silent! keepjumps %delete _
    return
  endif
  if a:number
    let digit = len(len(a:content) . '')
    let format = printf('%%%dd %%s', digit)
    let content = map(
          \ copy(a:indices),
          \ 'printf(format, v:val + 1, a:content[v:val])'
          \)
  else
    let content = map(copy(a:indices), 'a:content[v:val]')
  endif
  silent! call setline(1, content)
  execute printf('silent! keepjumps %d,$delete _', len(a:indices) + 1)
endfunction

function! s:update_hlsearch(pattern, ignorecase) abort
  if empty(a:pattern)
    silent nohlsearch
  else
    silent! execute printf(
          \ '/%s\%%(%s\)/',
          \ a:ignorecase ? '\c' : '\C',
          \ a:pattern
          \)
  endif
endfunction

function! s:update_statusline(context) abort
  let statusline = [
        \ '%%#ListaStatuslineFile# %s ',
        \ '%%#ListaStatuslineMiddle#%%=',
        \ '%%#ListaStatuslineMatcher# Matcher: %s (C-^ to switch) ',
        \ '%%#ListaStatuslineMatcher# Case: %s (C-_ to switch) ',
        \ '%%#ListaStatuslineIndicator# %d/%d',
        \]
  let &l:statusline = printf(
        \ join(statusline, ''),
        \ expand('%'),
        \ a:context.matchers[a:context.matcher].name,
        \ a:context.ignorecase ? 'ignore' : 'normal',
        \ len(a:context.indices),
        \ len(a:context.content),
        \)
endfunction

function! s:move_to_prev_line() abort
  let size = max([len(b:context.indices), 1])
  if b:context.cursor is# 1
    let b:context.cursor = b:context.wrap_around ? size : 1
  else
    let b:context.cursor -= 1
  endif
  call cursor(b:context.cursor, 1, 0)
  redraw
  call feedkeys(" \<C-h>", 'n')   " Stay TERM cursor on cmdline
  return ''
endfunction

function! s:move_to_next_line() abort
  let size = max([len(b:context.indices), 1])
  if b:context.cursor is# size
    let b:context.cursor = b:context.wrap_around ? 1 : size
  else
    let b:context.cursor += 1
  endif
  call cursor(b:context.cursor, 1, 0)
  redraw
  call feedkeys(" \<C-h>", 'n')   " Stay TERM cursor on cmdline
  return ''
endfunction

function! s:switch_to_prev_matcher() abort
  let size = len(b:context.matchers)
  if b:context.matcher is# 0
    let b:context.matcher = size - 1
  else
    let b:context.matcher -= 1
  endif
  call timer_start(0, funcref('s:update'))
  call feedkeys(" \<C-h>", 'n')   " Stay TERM cursor on cmdline
  return ''
endfunction

function! s:switch_to_next_matcher() abort
  let size = len(b:context.matchers)
  if b:context.matcher is# (size - 1)
    let b:context.matcher = 0
  else
    let b:context.matcher += 1
  endif
  call timer_start(0, funcref('s:update'))
  call feedkeys(" \<C-h>", 'n')   " Stay TERM cursor on cmdline
  return ''
endfunction

function! s:switch_ignorecase() abort
  let b:context.ignorecase = !b:context.ignorecase
  call timer_start(0, funcref('s:update'))
  call feedkeys(" \<C-h>", 'n')   " Stay TERM cursor on cmdline
  return ''
endfunction
