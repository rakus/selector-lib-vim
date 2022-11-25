"
" FILE: selectorwindow.vim
"
" ABSTRACT: Select-window to be used by other scripts
"
" AUTHOR: Ralf Schandl
"

" Open selector window
"
function! selectorwindow#Selector(title, list, callback, options)

    " store window the selector was called from
    let caller_winid = win_getid()

    let Callback = selectorcore#ToFuncref("callback", a:callback)

    let selector_options = selectorcore#InitOptions(a:options, g:selector#WINDOW)

    let pre_ctx = {
                \ 'winid': -1,
                \ 'bufnr': -1,
                \ 'type': g:selector#WINDOW,
                \ 'caller_winid': caller_winid,
                \ 'entry_list': [],
                \ 'text_list': [],
                \ 'text_map': [],
                \ 'entry_tree': v:false,
                \ 'start_col': 0,
                \ 'callback': Callback,
                \ 'transparent': 0,
                \ 'hidden_mark': -1,
                \ 'change_count': 0,
                \ 'options': selector_options,
                \ }

    let [ entry_list, text_list, text_map ] = selectorcore#CreateSelectorContent(pre_ctx, a:list)
    if len(text_list) == 0
        echo "Selector \"" . a:title . "\" empty"
        return
    endif

    let pre_ctx.entry_list = entry_list
    let pre_ctx.text_list = text_list
    let pre_ctx.text_map = text_map

    if selector_options.position == g:selector#POPUP_TOP
                \ || selector_options.position == g:selector#POPUP_CENTER
                \ ||  selector_options.position == g:selector#POPUP_CURSOR
        "top
        let height = &lines/3
        exe(height . "new -[ " . a:title . " ]-")
    elseif selector_options.position == g:selector#POPUP_TOP_LEFT
                \ || selector_options.position == g:selector#POPUP_BOT_LEFT
        "left
        let width = &columns/3
        exe("topleft " . width . "vnew -[ " . a:title . " ]-")

    elseif  selector_options.position == g:selector#POPUP_TOP_RIGHT
                \ || selector_options.position == g:selector#POPUP_BOT_RIGHT
        "right
        let width = &columns/3
        exe("botright " . width . "vnew -[ " . a:title . " ]-")
    elseif selector_options.position == g:selector#POPUP_BOT
        " bottom
        let height = &lines/3
        exe("botright " . height . "new -[ " . a:title . " ]-")
    endif

    let bufnr = bufnr('%')

    let b:ctx = pre_ctx
    let b:ctx.winid = win_getid()
    let b:ctx.bufnr = bufnr

    setlocal report=9999
    setlocal nowrap
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=wipe
    setlocal modifiable
    setlocal cursorline
    setlocal nobuflisted
    setlocal undolevels=-1

    " insert the lists
    call setline(1, text_list)

    " No changes allowed!
    setlocal nomodified
    setlocal nomodifiable

    " highlighting for the headers
    exe("sy match String    \"^-=.*=-$\"")


    call setwinvar(win_getid(), "selector_ctx", b:ctx)

    for m in selector_options.mappings
        exe "noremap <silent> <buffer> " . m.key . "  :call selectorwindow#SelectorCallback(b:ctx, \"" . m.key . "\", 0)<cr>"
    endfor

    " mappings
    if selector_options.disable_select == 0
        let b:CR = "\<CR>"
        noremap <silent> <buffer> <2-LeftMouse> :call selectorwindow#SelectorCallback(b:ctx, b:CR, 1)<cr>
        noremap <silent> <buffer> <cr>          :call selectorwindow#SelectorCallback(b:ctx, b:CR, 1)<cr>
        noremap <silent> <buffer> <space>       :call selectorwindow#SelectorCallback(b:ctx, " ", 1)<cr>
    endif
    noremap <silent> <buffer> <nowait> g        :1<cr>
    noremap <silent> <buffer> <nowait> W        :set invwrap<cr>
    noremap <silent> <buffer> ?                 :call selectorwindow#SelectorCallback(b:ctx, "?", 0)<cr>
    if b:ctx.entry_tree
        noremap <silent> <buffer> <nowait> <C-G>    :call selectorwindow#SelectorCallback(b:ctx, "<C-G>", 1)<cr>
    endif

    noremap <silent> <buffer> <nowait> x        :call selectorwindow#CloseSelector(b:ctx)<cr>

    exe "1"
endfunction

function! selectorwindow#UpdateContent(ctx, list, line=0)
    let [ entry_list, text_list, text_map ] = selectorcore#CreateSelectorContent(a:ctx, a:list)
    let a:ctx.entry_list = entry_list
    let a:ctx.text_map = text_map
    let a:ctx.text_list = text_list

    let a:ctx.change_count = a:ctx.change_count + 1

    call selectorwindow#SetText(a:ctx)
endfunction

function! selectorwindow#SetText(ctx)
    let oldwin = win_getid()
    try
        call win_gotoid(a:ctx.winid)
        let bufnr = bufnr('%')
        if bufnr != a:ctx.bufnr
            unlet! w:ctx
            throw "Selector gone"
        endif

        let save_cursor = getcurpos()
        setlocal modifiable
        execute "%d"
        call setline(1, a:ctx.text_list)
        setlocal nomodifiable
        setlocal nomodified
        call setpos('.', save_cursor)
    finally
        call win_gotoid(oldwin)
    endtry
endfunction

function selectorwindow#UpdateTitle(ctx, title)
    "call popup_setoptions(a:ctx.winid, #{title: a:title})
endfunction

function! selectorwindow#CloseSelector(ctx)
    try
        exe a:ctx.bufnr . "bunload!"
    catch
        " ignore
        echomsg v:exception
    endtry
endfunc
"
" Called when a line was selected. It then calles the callback function.
"
function! selectorwindow#SelectorCallback(ctx, key, close)
    let lineno     = line(".")
    let selectWinId = win_getid()

    let entry = a:ctx.text_map[lineno - 1]
    let entry_index = lineno - 1


    if selectorcore#CommonSelectorFilter(a:ctx, a:key, entry, entry_index) != 0
        return 1
    elseif a:key == "\<C-G>"
        let i = entry_index
        let old_level = entry.Level
        while i > 0 && a:ctx.text_map[i].Level >= old_level
            let i = i -1
            call win_execute(a:ctx.winid, '-1')
        endwhile
    endif
    return 0
endfunction

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
