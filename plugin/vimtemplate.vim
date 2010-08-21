" vim:foldmethod=marker:fen:
scriptencoding utf-8

" INCLUDE GUARD {{{
if exists('g:loaded_vimtemplate') && g:loaded_vimtemplate != 0
    finish
endif
let g:loaded_vimtemplate = 1
" }}}
" SAVING CPO {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" SCOPED VARIABLES {{{
let s:caller_bufnr = -1
" }}}
" GLOBAL VARIABLES {{{
if !exists('g:vt_template_dir_path')
    let g:vt_template_dir_path = '~/.vim/template'
endif
if !exists('g:vt_no_command')
    let g:vt_no_command = 0
endif
if !exists('g:vt_no_default_mappings')
    let g:vt_no_default_mappings = 0
endif
if !exists('g:vt_open_command')
    let g:vt_open_command = '7new'
endif
if !exists('g:vt_files_metainfo')
    let g:vt_files_metainfo = {}
endif
if !exists('g:vt_author')
    let g:vt_author = ''
endif
if !exists('g:vt_email')
    let g:vt_email = ''
endif
if !exists('g:vt_buffer_no_default_mappings')
    let g:vt_buffer_no_default_mappings = 0
endif
" }}}

" FUNCTION DEFINITION {{{
function! s:warn(msg) "{{{
    echohl WarningMsg
    echo a:msg
    echohl None
endfunction "}}}

function! s:glob(expr) "{{{
    return split(glob(a:expr), '\n')
endfunction "}}}

function! s:compile_template(lines, path) "{{{
    let ret = []
    for text in a:lines
        let text = s:expand_template_syntax(text, a:path)
        call add(ret, text)
        call s:eval_modeline(text, a:path)
    endfor
    return ret
endfunction "}}}

function! s:expand_template_syntax(line, path) "{{{
    let line = a:line
    let regex = '\m<%\s*\(.\{-}\)\s*%>'
    let path = expand('%') == '' ? a:path : expand('%')
    let replaced = ''

    let lis = matchlist(line, regex)
    call filter(lis, '! empty(v:val)')

    while !empty(lis)
        if lis[1] =~# '\m\s*eval:'
            let code = substitute(lis[1], '\m\s*eval:', '', '')
            let replaced = eval(code)
        else
            if lis[1] ==# 'path'
                let replaced = path

            elseif lis[1] ==# 'filename'
                let replaced = fnamemodify(path, ':t')

            elseif lis[1] ==# 'filename_noext'
                let replaced = fnamemodify(path, ':t:r')

            elseif lis[1] ==# 'filename_ext'
                let replaced = fnamemodify(path, ':e')

            elseif lis[1] ==# 'filename_camel'
                let replaced = fnamemodify(path, ':t:r')
                let m = get(matchlist(replaced, '[-_].'), 0, '')
                while m != ''
                    let replaced = substitute(replaced, m, toupper(m[1]), '')
                    let m = get(matchlist(replaced, '[-_].'), 0, '')
                endwhile
                let replaced = toupper(replaced[0]) . replaced[1:]

            elseif lis[1] ==# 'filename_snake'
                let replaced = fnamemodify(path, ':t:r')
                let camels = split(replaced, '\%([A-Z]\)\@=')
                let camels =
                            \[tolower(strpart(camels[0], 0, 1)).strpart(camels[0], 1)] +
                            \map(camels[1:], '"_".tolower(strpart(v:val, 0, 1)).strpart(v:val, 1)')
                let replaced = join(camels, '')

            elseif lis[1] ==# 'parent_dir'
                let replaced = fnamemodify(path, ':p:h')

            elseif lis[1] ==# 'author'
                let replaced = g:vt_author

            elseif lis[1] ==# 'email'
                let replaced = g:vt_email
            endif
        endif

        let line = substitute(line, regex, replaced, '')
        let lis = matchlist(line, regex)
        call filter(lis, '! empty(v:val)')
    endwhile

    return line
endfunction "}}}

function! s:eval_modeline(line, path) "{{{
    let line = a:line
    " according to vim help, there are 2 types of modeline.
    "   [text]{white}{vi:|vim:|ex:}[white]{options}
    "   [text]{white}{vi:|vim:|ex:}[white]se[t] {options}:[text]
    let regex = '\m[ \t]*\(vi\|vim\|ex\):\(.*\):'
    let match = get(matchlist(line, regex), 2, '')

    if match != ''
        " NOTE set opt=: is NG but not needed to support it maybe
        for opt in split(match, ':')
            if opt =~# '\mset\='
                let opt = substitute(opt, '\mset\=', 'setlocal', '')
                execute opt
            else
                let opt = 'setlocal ' . opt
                execute opt
            endif
        endfor
    endif
endfunction "}}}

function! s:buffer_open() "{{{
    " get path of template file
    let relpath = getline('.')
    let template_path = expand(g:vt_template_dir_path) . '/' . relpath
    if !filereadable(template_path)
        call s:warn(printf("can't read '%s'", template_path))
        return
    endif

    close
    " paste buffer into main buffer
    try
        let text = readfile(template_path)
    catch
        call s:warn(v:exception)
        return
    endtry
    let text = s:compile_template(text, template_path)
    %delete _
    call setline(1, text)

    if has_key(g:vt_files_metainfo, relpath)
        for [k, v] in items(g:vt_files_metainfo[relpath])
            if k ==# 'filetype'
                let &l:filetype = v
            endif
        endfor
    endif
endfunction "}}}

function! s:bufleave() "{{{
    let winnr = bufwinnr(s:caller_bufnr)
    if winnr == -1
        return
    endif
    execute winnr 'wincmd w'

    let s:caller_bufnr = -1
endfunction "}}}

function! s:show_files_list() "{{{
    let winnr = bufwinnr(s:caller_bufnr)
    if winnr != -1
        execute winnr 'wincmd w'
        return
    endif

    let template_dir = expand(g:vt_template_dir_path)
    if !isdirectory(template_dir)
        call s:warn("No such dir: " . template_dir)
        return
    endif

    execute g:vt_open_command
    let s:caller_bufnr = bufnr('%')

    " Write template files list to the buffer.
    let template_files_list = s:glob(template_dir . '/*')
    call map(template_files_list, 'v:val[strlen(template_dir) + 1 :]')
    call setline(1, template_files_list)

    setlocal bufhidden=wipe
    setlocal buftype=nofile
    setlocal cursorline
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal noswapfile

    augroup vimtemplate
        autocmd!
        autocmd BufLeave * call s:bufleave()
    augroup END

    nnoremap <buffer><silent> <Plug>(vimtemplate-buffer-open)   :<C-u>call <SID>buffer_open()<CR>
    nnoremap <buffer><silent> <Plug>(vimtemplate-buffer-close)  :<C-u>close<CR>
    if !g:vt_buffer_no_default_mappings
        nmap <buffer> <CR>  <Plug>(vimtemplate-buffer-open)
        nmap <buffer> q     <Plug>(vimtemplate-buffer-close)
    endif

    file `="__template__"`

    setfiletype vimtemplate
endfunction "}}}
" }}}

" COMMAND {{{
if !g:vt_no_command
    command! VimTemplate call s:show_files_list()
endif
" }}}

" MAPPING {{{
nnoremap <silent> <Plug>(vimtemplate-open)   :<C-u>call <SID>show_files_list()<CR>

if !g:vt_no_default_mappings
    nmap <unique> gt    <Plug>(vimtemplate-open)
endif
" }}}

" RESTORE CPO {{{
let &cpo = s:save_cpo
" }}}
