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
let s:cache_filetype_files = { 'cached':0, 'filenames':{} }
" }}}
" GLOBAL VARIABLES {{{
if !exists('g:vt_template_dir_path')
    let g:vt_template_dir_path = '$HOME/.vim/template'
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
if !exists('g:vt_filetype_files')
    let g:vt_filetype_files = ''
endif
if !exists('g:vt_author')
    let g:vt_author = ''
endif
if !exists('g:vt_email')
    let g:vt_email = ''
endif
" }}}

" FUNCTION DEFINITION {{{
function! s:warn(msg) "{{{
    echohl WarningMsg
    echo a:msg
    echohl None
endfunction "}}}

function! s:glob(expr) "{{{
    let files = split(glob(a:expr), '\n')

    call map(files, 'fnamemodify(v:val, ":t")')
    call filter(files, 'v:val !=# "." && v:val !=# ".."')

    return files
endfunction "}}}

function! s:get_filetype_of(path) "{{{
    " NOTE: a:path must exist.

    if ! s:cache_filetype_files.cached
        " save cache to s:cache_filetype_files
        for pair in split(g:vt_filetype_files, ',')
            let [fname_tail; filetype] = split(pair, '=')
            if empty(filetype)
                continue
            endif

            let s:cache_filetype_files.filenames[fname_tail] = filetype[0]
        endfor
        " cached
        let s:cache_filetype_files.cached = 1
    endif

    let tail = fnamemodify(a:path, ':t')
    if has_key(s:cache_filetype_files.filenames, tail)
        return s:cache_filetype_files.filenames[tail]
    else
        return ''
    endif
endfunction "}}}

function! s:apply_template(text, path) "{{{
    let text = a:text
    let [i, len] = [0, len(text)]

    while i < len
        " template syntax
        let text[i] = s:expand_template_syntax(text[i], a:path)
        " modeline in template file
        call s:eval_modeline(text[i], a:path)

        let i = i + 1
    endwhile

    return text
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

function! s:open_file_on_cursol() "{{{
    " get path of template file
    let template_path = getline('.')
    if template_path == ''
        return
    endif

    if !filereadable(template_path)
        call s:warn(printf("can't read '%s'", template_path))
        return
    endif

    call s:close_list_buffer()
    " paste buffer into main buffer
    let text = readfile(template_path)
    let text = s:apply_template(text, template_path)
    call s:multi_setline(text)

    let ftype = s:get_filetype_of(template_path)
    if ftype != ''
        execute 'setlocal ft=' . ftype
    endif
endfunction "}}}

function! s:close_list_buffer() "{{{
    if winnr('$') != 1
        close
        " switch to caller window
        let winnr = bufwinnr(s:caller_bufnr)
        if winnr == -1
            return
        endif
        execute winnr.'wincmd w'
    endif
    let s:caller_bufnr = -1
endfunction "}}}

function! s:multi_setline(lines) "{{{
    " delete all
    %delete _

    let reg_z = getreg('z', 1)
    let reg_z_type = getregtype('z')
    let @z = join(a:lines, "\n")

    " write all lines
    silent put z
    " delete the top of one waste blank line
    normal! ggdd

    call setreg('z', reg_z, reg_z_type)
endfunction "}}}

function! s:show_files_list() "{{{

    " return if window exists
    let winnr = bufwinnr(s:caller_bufnr)
    if winnr != -1
        execute winnr.'wincmd w'
        return
    endif

    " open list buffer
    execute g:vt_open_command
    " no template directory
    if !isdirectory(expand(g:vt_template_dir_path))
        close
        call s:warn("No such dir: " . expand(g:vt_template_dir_path))
        return
    endif
    let s:caller_bufnr = bufnr('%')

    " write template files list to main buffer
    let template_files_list = s:glob(expand(g:vt_template_dir_path) . '/*')
    call map(template_files_list, 'expand(g:vt_template_dir_path) . "/" . v:val')
    call s:multi_setline(template_files_list)


    """ settings """

    setlocal bufhidden=wipe
    setlocal buftype=nofile
    setlocal cursorline
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal noswapfile

    nnoremap <buffer><silent> <CR>  :call <SID>open_file_on_cursol()<CR>
    nnoremap <buffer><silent> q     :call <SID>close_list_buffer()<CR>

    file __template__
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
