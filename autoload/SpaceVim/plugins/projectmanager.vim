"=============================================================================
" projectmanager.vim --- project manager for SpaceVim
" Copyright (c) 2016-2017 Shidong Wang & Contributors
" Author: Shidong Wang < wsdjeg at 163.com >
" URL: https://spacevim.org
" License: MIT license
"=============================================================================

" project item:
" {
"   "path" : "path/to/root",
"   "name" : "name of the project, by default it is name of root directory",
"   "type" : "git maven or svn",
" }
"


let s:project_paths = {}

function! s:cache_project(prj) abort
  if !has_key(s:project_paths, a:prj.path)
    let s:project_paths[a:prj.path] = a:prj
    let desc = '[' . a:prj.name . '] ' . a:prj.path
    let cmd = "call SpaceVim#plugins#projectmanager#open('" . a:prj.path . "')"
    call add(g:unite_source_menu_menus.Projects.command_candidates, [desc,cmd])
  endif
endfunction

let g:unite_source_menu_menus =
      \ get(g:,'unite_source_menu_menus',{})
let g:unite_source_menu_menus.Projects = {'description':
      \ 'Custom mapped keyboard shortcuts                   [SPC] p p'}
let g:unite_source_menu_menus.Projects.command_candidates =
      \ get(g:unite_source_menu_menus.Projects,'command_candidates', [])

function! SpaceVim#plugins#projectmanager#list() abort
  Unite menu:Projects
endfunction

function! SpaceVim#plugins#projectmanager#open(project) abort
  let path = s:project_paths[a:project]['path']
  tabnew
  exe 'lcd ' . path
  Startify | VimFiler
endfunction

function! SpaceVim#plugins#projectmanager#current_name() abort
  return get(b:, '_spacevim_project_name', '')
endfunction

" this func is called when vim-rooter change the dir, That means the project
" is changed, so will call call the registered function.
function! SpaceVim#plugins#projectmanager#RootchandgeCallback() abort
  let project = {
        \ 'path' : getcwd(),
        \ 'name' : fnamemodify(getcwd(), ':t')
        \ }
  call s:cache_project(project)
  let g:_spacevim_project_name = project.name
  let b:_spacevim_project_name = g:_spacevim_project_name
  for Callback in s:project_callback
    call call(Callback, [])
  endfor
endfunction

let s:project_callback = []
function! SpaceVim#plugins#projectmanager#reg_callback(func) abort
  if type(a:func) == 2
    call add(s:project_callback, a:func)
  else
    call SpaceVim#logger#warn('can not register the project callback: ' . string(a:func))
  endif
endfunction

function! SpaceVim#plugins#projectmanager#current_root() abort
  let rootdir = getbufvar('%', 'rootDir', '')
  if empty(rootdir)
    let rootdir = s:change_to_root_directory()
  else
    call s:change_dir(rootdir)
    call SpaceVim#plugins#projectmanager#RootchandgeCallback() 
  endif
  return rootdir
endfunction

function! s:change_dir(dir) abort
    if isdirectory(a:dir)
      exe 'cd ' . fnamemodify(a:dir, ':p:h:h')
    else
      exe 'cd ' . fnamemodify(a:dir, ':p:h')
    endif
endfunction

let s:BUFFER = SpaceVim#api#import('vim#buffer')

function! SpaceVim#plugins#projectmanager#kill_project() abort
  let name = get(b:, '_spacevim_project_name', '')
  if name != ''
    call s:BUFFER.filter_do(
          \ {
          \ 'expr' : [
          \ 'buflisted(v:val)',
          \ 'getbufvar(v:val, "_spacevim_project_name") == "' . name . '"',
          \ ],
          \ 'do' : 'bd %d'
          \ }
          \ )
  endif

endfunction

let g:spacevim_project_rooter_patterns = ['.git/', '_darcs/', '.hg/', '.bzr/', '.svn/']

let g:spacevim_project_rooter_manual_only = 0
if !g:spacevim_project_rooter_manual_only
  augroup spacevim_project_rooter
    autocmd!
    autocmd VimEnter,BufEnter * call SpaceVim#plugins#projectmanager#current_root()
    autocmd BufWritePost * :call setbufvar('%', 'rootDir', '') | call SpaceVim#plugins#projectmanager#current_root()
  augroup END
endif
function! s:find_root_directory() abort
  let fd = expand('%:p')
  let dirs = []
  for pattern in g:spacevim_project_rooter_patterns
    let dir = SpaceVim#util#findDirInParent(pattern, fd)
    if !empty(dir)
      call SpaceVim#logger#info('Find project root:' . dir)
      call add(dirs, dir)
    endif
  endfor
  return s:sort_dirs(dirs)
endfunction


function! s:sort_dirs(dirs) abort
  let dirs = sort(a:dirs, funcref('s:compare'))
  let bufdir = getbufvar('%', 'rootDir', '')
  if bufdir ==# get(dirs, 0, '')
    return ''
  else
    let dir = dirs[0]
    call s:change_dir(dir)
    call setbufvar('%', 'rootDir', getcwd())
    return b:rootDir
  endif
endfunction

function! s:compare(d1, d2) abort
  return len(split(a:d1, '/')) - len(split(a:d2, '/'))
endfunction

function! s:change_to_root_directory() abort
  if s:find_root_directory()
    call SpaceVim#plugins#projectmanager#RootchandgeCallback() 
  endif
  return getbufvar('%', 'rootDir', '')
endfunction


" vim:set et nowrap sw=2 cc=80:
