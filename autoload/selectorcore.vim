"
" FILE: selectorcore.vim
"
" ABSTRACT: support functions for selector-popup/window
"
" AUTHOR: Ralf Schandl
"

" a selectable popup entry
const selectorcore#t_entry = 0
" a title line in the popup
const selectorcore#t_title = 1
" a empty line used as seperator
const selectorcore#t_blank = 2
const selectorcore#t_container = 3

function! selectorcore#CreateSelectorContent(ctx, entry_list, filter_re = "")
    let [ text_list, text_map, is_tree] = s:CreateContainerContent(a:entry_list, 0, "")
    let a:ctx.entry_tree = 1
    return [ a:entry_list, text_list, text_map ]
endfunction

" closed dir: ▸ (BLACK RIGHT-POINTING SMALL TRIANGLE)
" let s:ICON_DIR_CLOSED = "\u25B8 "
" opened dir: ▾ (BLACK DOWN-POINTING SMALL TRIANGLE)
" let s:ICON_DIR_OPEN   = "\u25BE "
" closed dir: ▶ (BLACK RIGHT-POINTING TRIANGLE)
const s:ICON_DIR_CLOSED = "\u25B6 "
" opened dir: ▼ (BLACK DOWN-POINTING TRIANGLE)
const s:ICON_DIR_OPEN   = "\u25BC "

function s:CreateContainerContent(list, level, filter_re = "")
    let text_list = []
    let text_map  = []

    let indent = repeat("  ", a:level)

    let childs = 0

    for entry in a:list
        if get(entry, "Hide", v:false) != v:false
            continue
        endif
        if !exists("entry.Childs")
            if entry.Display =~? a:filter_re
                let icon = ""
                if get(entry, "Icon", "") != ""
                    let icon = entry.Icon . " "
                endif
                call add(text_list, indent . icon . entry.Display)
                call add(text_map, #{ Level: a:level, Type: g:selectorcore#t_entry, Item: entry })
            endif
        else
            let childs = childs + 1
            if get(entry, "Open", 0) == 0
                let entry.Open = v:false
                call add(text_list, indent . s:ICON_DIR_CLOSED . entry.Display)
                call add(text_map, #{ Level: a:level, Type: g:selectorcore#t_container, Item: entry })
            else
                let entry.Open = v:true
                call add(text_list, indent . s:ICON_DIR_OPEN . entry.Display)
                call add(text_map, #{ Level: a:level, Type: g:selectorcore#t_container, Item: entry })
                "echo entry.Display . " Childs: " .  len(entry.Childs)
                let [ nt, nm, nc ] =  s:CreateContainerContent(entry.Childs, a:level + 1, a:filter_re)
                let childs = childs + nc
                call extend(text_list, nt)
                call extend(text_map, nm)
            endif
        endif
    endfor
    return [ text_list, text_map, childs > 0 ]
endfunction

function! selectorcore#HandleContainerChange(text_list, text_map, index)

    let container = a:text_map[a:index]
    "echo container.Item.Display . " " . a:index

    let start=a:index
    let end=a:index
    let max = len(a:text_map) - 1
    while end < max && a:text_map[end+1].Level > container.Level
        let end = end + 1
    endwhile

    if start == end && container.Item.Open == v:false
        " Was closed and still closed
        return
    endif

    " remove entries
    call remove(a:text_list, start, end)
    call remove(a:text_map, start, end)
    let [ nt, nm, ignored ] = s:CreateContainerContent([ container.Item ], container.Level, "")
    call extend(a:text_list, nt, a:index)
    call extend(a:text_map, nm, a:index)
endfunction



function! selectorcore#PopupEntryListFilter(entry_list, filter_re)
    let [ text_list, test_map, ignore ] = s:CreateContainerContent(a:entry_list, 0, a:filter_re)
    return [ text_list, test_map ]
endfunction

function! selectorcore#ToFuncref(name, callback)
    if type(a:callback) == v:t_string
        if trim(a:callback) == ''
            echoerr "Value of " . a:name . " is empty"
            return 1
        elseif ! exists('*' . a:callback)
            echoerr "Function for " . a:name . " does not exist: " . a:callback
            return 1
        endif
        return function(a:callback)
    elseif type(a:callback) == v:t_func
        return a:callback
    else
        throw "Invalid callback for " . a:name . ": " . a:callback
    endif
endfunction


function! selectorcore#InitOptions(options, selector_type)
    let popup_options = {
            \ 'disable_select': v:false,
            \ 'select_close': v:true,
            \ 'all_tabs': v:false,
            \ 'wrapped': v:true,
            \ 'support_filter': v:true,
            \ 'position': 'center',
            \ 'width': 100,
            \ 'width_flex': v:true,
            \ 'height': 100,
            \ 'height_flex': v:true,
            \ 'type': '',
            \ 'cursor_re': '',
            \ 'tree_events': v:false,
            \ 'tree_enter_select': v:false,
            \ 'minimize': v:false,
            \ 'select_help': 'select entry & close selector',
            \ 'mappings': [],
            \ 'user_data': {}
            \}

    for k in keys(a:options)
        if ! exists("popup_options[k]")
            throw "PopupSel: Invalid option: " . k
        endif
        let popup_options[k] = a:options[k]
    endfor

    let callback_keys = {}
    for mp in popup_options.mappings
        if mp.key =~ '^<.*>'
            let callback_keys[eval('"\' . mp.key . '"')] = mp
        else
            let callback_keys[mp.key] = mp
        endif
        if !exists("mp.item")
            let mp.item = 1
        endif
    endfor
    let popup_options.callback_keys = callback_keys

    let popup_options.selector_type = a:selector_type

    return popup_options
endfunction

function! selectorcore#ShowHelp(ctx)

    let fmt = "%-13s %s"
    let help = []

    if a:ctx.type == g:selector#POPUP
        call add(help, printf(fmt, 'j,k', 'move down/up'))
        call add(help, printf(fmt, 'h,l,0,$', 'scroll left/right'))
        call add(help, printf(fmt, '<C-F>,<C-B>', 'page down/up'))
        call add(help, printf(fmt, 'g,G', 'goto top/bottom'))
    endif
    if a:ctx.entry_tree
        call add(help, printf(fmt, '<C-G>', 'goto parent entry or top'))
    endif

    call add(help, printf(fmt, 'W', 'toggle wrapping'))

    if a:ctx.type == g:selector#POPUP && a:ctx.options.support_filter == v:true
        call add(help, printf(fmt, '/', 'filter content'))
        call add(help, printf(fmt, 'X', 'reset filter'))
    endif
    call add(help, printf(fmt, 'x', 'quit'))


    if a:ctx.options.disable_select == v:false || len(a:ctx.options.mappings) != 0
        call add(help, '---')
        if a:ctx.options.disable_select == v:false
            call add(help, printf(fmt, '<Enter>', a:ctx.options.select_help))
        endif

        for mp in a:ctx.options.mappings
            call add(help, printf(fmt, mp.key, mp.help))
        endfor
    endif

    if selector#PopupSupported()
        call popup_dialog(help, {
                    \ 'title':"[ Help - 'x' to close ]",
                    \ 'zindex':400,
                    \ 'filter': 'popup_filter_menu',
                    \ 'highlight': 'WarningMsg'})
    else
        for entry in help
            echo entry
        endfor
    endif

endfunction


function! selectorcore#CommonSelectorFilter(ctx, key, entry, entry_index)

    let key = a:key

    if key == '?'
        call selectorcore#ShowHelp(a:ctx)
        " WARUM? call win_execute(a:id, '-' .  min([ popup_getpos(a:id)['core_height'], ln ]))
    elseif a:ctx.entry_tree && key == "\<C-G>"
        let i = a:entry_index
        let old_level = a:entry.Level
        while i > 0 && a:ctx.text_map[i].Level >= old_level
            let i = i -1
            call win_execute(a:ctx.winid, '-1')
        endwhile
    elseif key == 'W'
        call s:ToogleWrap(a:ctx)
    elseif key == 'x'
        call s:SelectorClose(a:ctx)
    elseif (key == "\<cr>" || key == ' ')
        if a:entry != {} && get(a:entry.Item, "Selectable", v:true) == v:true
            if a:entry.Type == g:selectorcore#t_container && (key == ' ' || (key == "\<cr>" && !a:ctx.options.tree_enter_select))
                if a:entry.Item.Open == v:true
                    if a:ctx.options.tree_events
                        call s:CallCallback(a:ctx, '<COLLAPSE>', a:entry.Item)
                    endif
                    let a:entry.Item.Open = v:false
                else
                    if a:ctx.options.tree_events
                        call s:CallCallback(a:ctx, '<EXPAND>', a:entry.Item)
                    endif
                    let a:entry.Item.Open = v:true
                endif
                call selectorcore#HandleContainerChange(a:ctx.text_list, a:ctx.text_map, a:entry_index)
                call s:SetText(a:ctx)
            elseif a:ctx.options.disable_select == v:false
                if a:ctx.options.select_close
                    call s:SelectorClose(a:ctx, line('.', a:ctx.winid))
                else
                    let cbrc = s:CallCallback(a:ctx, '<SELECT>', a:entry.Item)
                    if cbrc == 1
                        call s:SelectorHide(a:ctx, 1)
                    elseif cbrc == 2
                        call s:SelectorClose(a:ctx)
                    endif
                endif
            endif
        endif
    elseif has_key(a:ctx.options.callback_keys, key)
        if (a:entry.Type != g:selectorcore#t_container || a:ctx.options.tree_events) && get(a:entry.Item, "Selectable", v:true) == v:true
            let mp = a:ctx.options.callback_keys[key]
            let old_open = get(a:entry.Item, "Open", 0)
            let old_change_count = a:ctx.change_count

            let cbrc = s:CallCallback(a:ctx, mp.key, a:entry.Item)
            if cbrc == 1
                call s:SelectorHide(a:ctx, 1)
            elseif cbrc == 2
                call s:SelectorClose(a:ctx)
            elseif old_change_count == a:ctx.change_count
                if a:entry.Type == g:selectorcore#t_container
                    if old_open != a:entry.Item.Open
                        call selectorcore#HandleContainerChange(a:ctx.text_list, a:ctx.text_map, a:entry_index)
                        call s:SetText(a:ctx)
                    endif
                endif
            endif
        endif
    else
        return 0
    endif
    return 1
endfunction


function! s:ToogleWrap(ctx)
    if a:ctx.type == g:selector#POPUP
        if popup_getoptions(a:ctx.winid).wrap == 1
            call popup_setoptions(a:ctx.winid, {'wrap':0})
        else
            let ln = line('.', a:ctx.winid)
            if a:ctx.start_col != 0
                let a:ctx.start_col = 0
                call popup_settext(a:ctx.winid, a:ctx.text_list)
            endif
            call popup_setoptions(a:ctx.winid, {'wrap':1})
            "redraw!
        endif
    else
        call win_execute(a:ctx.winid; "set invwrap")
    endif
endfunction


function! s:SelectorClose(ctx, line=-1)
    if a:ctx.type == g:selector#POPUP
        call popup_close(a:ctx.winid, a:line)
    else
        if a:line > 0
            let item = a:ctx.text_map[a:line - 1]
            cal s:CallCallback(a:ctx, "<SELECT>", item.Item)
        endif
        call selectorwindow#CloseSelector(a:ctx)
    endif
endfunction

function! s:SelectorHide(ctx, yes_no)
    if a:ctx.type == g:selector#POPUP
        let visible = popup_getpos(a:ctx.winid).visible
        if a:yes_no && visible
            call popup_hide(a:ctx.winid)
        elseif !a:yes_no && !visible
            call popup_show(a:ctx.winid)
        endif
    endif
endfunction

function! s:SetText(ctx)
    if a:ctx.type == g:selector#POPUP
        call popup_settext(a:ctx.winid, a:ctx.text_list)
    else
        call selectorwindow#SetText(a:ctx)
    endif
endfunction

function! s:CallCallback(ctx, event, item)
    let rc = 0
    try
        call win_gotoid(a:ctx.caller_winid)
        let rc = a:ctx.callback(a:ctx.winid, a:ctx.options.user_data, a:event, a:item)
    catch /.*/
		echohl WarningMsg | echo v:exception | echohl None
        let rc = 0
    finally
        call win_gotoid(a:ctx.winid)
    endtry
    return rc
endfunction




"
"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
