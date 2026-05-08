syntax on
colorscheme monokai
set encoding=utf-8
set fileencodings=utf-8,iso-2022-jp,ucs-bom,sjis,euc-jp,cp932,default,latin1
" Emacsキーバインド
inoremap <silent> <C-p> <Up>
inoremap <silent> <C-n> <Down>
inoremap <silent> <C-f> <Right>
inoremap <silent> <C-b> <Left>
inoremap <silent> <C-a> <Home>
inoremap <silent> <C-e> <End>
inoremap <silent> <C-h> <BS>
inoremap <silent> <C-d> <Del>
inoremap <silent> <C-k> <ESC>:EmacsKillCommand<CR>a

cnoremap <C-p> <Up>
cnoremap <C-n> <Down>
cnoremap <C-f> <Right>
cnoremap <C-b> <Left>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>
cnoremap <C-h> <BS>
cnoremap <C-d> <Del>
cnoremap <C-k> <Right><C-\>egetcmdline()[:getcmdpos()-2]<CR><BS>


" <C-k>自作コマンド
command! -nargs=0 EmacsKillCommand call EmacsKillCommand()
function! EmacsKillCommand()
  let s:currentLine = getline('.')
  let s:nextLine = getline(line('.')+1)
  let s:currentCol = col('.')
  let s:endCol = col('$')-1

  if s:currentLine == ""        " 現在の行が空白か判定
    :normal dd
  else
    if s:currentCol == s:endCol " カーソルが最終位置かどうか判定
      if s:nextLine == ""       " 次の行が空行か判定
        :normal J
      else
        :normal Jh
      endif
    elseif s:currentCol == 1    " 行の頭か判定
      normal D
    else
      :normal lD
    endif
  endif
endfunction

