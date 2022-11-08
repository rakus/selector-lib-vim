"
" FILE: selectorpopup.vim
"
" ABSTRACT: Select-popup to be used by other scripts
"
" AUTHOR: Ralf Schandl
"

" the window id of the popup
let g:selector_popup_set = {}

" mouse keys
let s:MOUSE_KEYCODES = [
            \ "\<LeftMouse>",     "\<MiddleMouse>",     "\<RightMouse>",
            \ "\<2-LeftMouse>",   "\<2-MiddleMouse>",   "\<2-RightMouse>",
            \ "\<2-S-LeftMouse>", "\<2-S-MiddleMouse>", "\<2-S-RightMouse>",
            \ "\<3-LeftMouse>",   "\<3-MiddleMouse>",   "\<3-RightMouse>",
            \ "\<3-S-LeftMouse>", "\<3-S-MiddleMouse>", "\<3-S-RightMouse>",
            \ "\<4-LeftMouse>",   "\<4-MiddleMouse>",   "\<4-RightMouse>",
            \ "\<4-S-LeftMouse>", "\<4-S-MiddleMouse>", "\<4-S-RightMouse>",
            \ "\<A-LeftMouse>",   "\<A-MiddleMouse>",   "\<A-RightMouse>",
            \ "\<C-LeftMouse>",   "\<C-MiddleMouse>",   "\<C-RightMouse>",
            \ "\<S-LeftMouse>",   "\<S-MiddleMouse>",   "\<S-RightMouse>",
            \ "\<LeftDrag>",   "\<LeftRelease>",
            \ "\<MiddleDrag>", "\<MiddleRelease>",
            \ "\<RightDrag>",  "\<RightRelease>",
            \ "\<X1Mouse>",    "\<X2Mouse>",
            \]

"
" Open a popup selector.
"
" title:
"     The title to use for the popup.
"
" list:
"     This is a list of dictionaries with the following content:
"     [
"       { 'Display': '<display string>', ... },
"       ...
"     ]
"
"     The list must contain dictionary objects that contain an entry with
"     the key "Display". This String is used for display. Additional
"     dictionary entries are allowed.
"
"     The selected dictionary is handed to the callback.
"
" callback:
"     Callback function to be called when a entry is selected. Gets the
"     dictionary from the list, that corresponds to the selected
"     line.
"
" options:
"     Container for for additional options.
"
function! selectorpopup#Selector(title, list, callback, options)

    let caller_winid = win_getid()

    " Check and assign the callback
    let Callback = selectorcore#ToFuncref("callback", a:callback)

    let selector_options = selectorcore#InitOptions(a:options, g:selector#POPUP)

    let ctx = {
                \ 'winid': -1,
                \ 'title': a:title,
                \ 'type': g:selector#POPUP,
                \ 'caller_winid': caller_winid,
                \ 'entry_list': [],
                \ 'text_list': [],
                \ 'text_map': [],
                \ 'entry_tree': v:false,
                \ 'start_col': 0,
                \ 'callback': Callback,
                \ 'filtering': 0,
                \ 'filter_input': "",
                \ 'filter_match_id': -1,
                \ 'change_count': 0,
                \ 'minimized': v:false,
                \ 'options': selector_options
                \ }

    let [ entry_list, text_list, text_map ] = selectorcore#CreateSelectorContent(ctx, a:list)
    if len(text_list) == 0
        call popup_notification("PopupSelector \"" . a:title . "\" empty", {})
        return
    endif

    let ctx.entry_list = entry_list
    let ctx.text_list = text_list
    let ctx.text_map = text_map
    for e in text_map
        if e.Type == g:selectorcore#t_container
            let ctx.entry_tree = v:true
            break
        endif
    endfor

    let [ max_height, width ] = s:CalculateTextListDimensions(text_list)

    if selector_options.height != 0
        if selector_options.height < 1 || selector_options.height > 100
            let selector_options.height = 100
        endif
        let win_height = &lines - 2 - (&laststatus == 2 ? 2:1)
        let max_height = ((win_height) * selector_options.height)/100
        if selector_options.height_flex
            let min_height = 1
        else
            let min_height = max_height
        endif
    else
        let min_height = max_height
    endif
    if selector_options.width != 0
        if selector_options.width < 1 || selector_options.width > 100
            let selector_options.width = 100
        endif
        let max_width = ((&columns - 2) * selector_options.width)/100
        if selector_options.width_flex
            let min_width = 1
        else
            let min_width = max_width
        endif
    endif

    let popup_options = {
                \ 'callback': function('s:PopupSelectorCallback'),
                \ 'filter': function('s:PopupSelectorFilter'),
                \ 'wrap': selector_options.wrapped,
                \ 'maxheight': max_height,
                \ 'maxwidth': width,
                \ 'minheight': min_height,
                \ 'minwidth': width,
                \ 'drag': v:true,
                \ 'resize': v:true,
                \ 'close': "button",
                \}
    if selector_options.position == g:selector#POPUP_AWAY
        let l = line('.')
        let r = screenpos(win_getid(), l, 1)['row']
        if r < (&lines / 2)
            let  selector_options.position = g:selector#POPUP_BOT
        else
            let  selector_options.position = g:selector#POPUP_TOP
        endif
    endif

    if selector_options.position == g:selector#POPUP_CENTER
        let popup_options.pos = 'center'
    elseif selector_options.position == g:selector#POPUP_TOP
        let popup_options.pos = 'topleft'
        let popup_options.line = 1
        let popup_options.col = (&columns - width) / 2
    elseif selector_options.position == g:selector#POPUP_TOP_LEFT
        let popup_options.pos = 'topleft'
        let popup_options.line = 1
        let popup_options.col = 1
    elseif selector_options.position == g:selector#POPUP_TOP_RIGHT
        let popup_options.pos = 'topright'
        let popup_options.line = 1
        let popup_options.col = &columns
    elseif selector_options.position == g:selector#POPUP_BOT
        let popup_options.pos = 'botleft'
        let popup_options.line = &lines
        let popup_options.col = (&columns - width) / 2
    elseif selector_options.position == g:selector#POPUP_BOT_LEFT
        let popup_options.pos = 'botleft'
        let popup_options.line = &lines
        let popup_options.col = 1
    elseif selector_options.position == g:selector#POPUP_BOT_RIGHT
        let popup_options.pos = 'botright'
        let popup_options.line = &lines
        let popup_options.col = &columns
    elseif selector_options.position == g:selector#POPUP_CURSOR
        let l = line('.')
        let c = col('.')
        let r = screenpos(win_getid(), l, c)['row']
        "echomsg "Row:" . r . " Lines:" . &lines . " Result" . (r < (&lines / 2))
        if r < (&lines / 2)
            let popup_options.pos = 'topleft'
            let nh = &lines - r
            let r += 1
        else
            let popup_options.pos = 'botleft'
            let r -= 1
            let nh = r
        endif
        let popup_options.line = r
        let popup_options.col = (&columns - width) / 2

        let popup_options.maxheight = min([len(text_list), nh - 2 ])

    endif

    if a:title != ''
        let popup_options.title = "[ " . a:title . " ]"
    endif

    if selector_options.all_tabs
        let popup_options.tabpage=-1
    endif

    let popup = popup_menu(text_list, popup_options)
    "let s:popup = popup_create(text_list, popup_options)
    let g:selector_popup_set[string(popup)] = popup

    let ctx.winid = popup

    call setwinvar(popup, "selector_ctx", ctx)

    "while s:GetLineEntry(ctx, line('.', popup)).Type != g:selectorcore#t_entry
    "    call win_execute(popup, 'g')
    "endwhile

    if selector_options.cursor_re != ''
        try
            call win_execute(popup, "/" . selector_options.cursor_re)
        catch
            echo "ERROR: cursor_re failed: " . v:exception
        endtry
    endif

    return popup

endfunction

function! selectorpopup#UpdateContent(ctx, list, line)
    let [ entry_list, text_list, text_map] = selectorcore#CreateSelectorContent(a:ctx, a:list, a:ctx.filter_input)
    let ctx = s:getctx(a:ctx.winid)
    let ctx.entry_list = entry_list
    let ctx.text_map = text_map
    let ctx.text_list = text_list
    let ctx.change_count = ctx.change_count + 1
    call popup_settext(a:ctx.winid, text_list)
    if a:line < 1
        if line('.', a:ctx.winid) > (len(text_list) + 1)
            call win_execute(a:ctx.winid, '$')
        endif
    else
        call win_execute(a:ctx.winid, '' . a:line)
    endif
endfunction

function selectorpopup#UpdateTitle(ctx, title)
    call popup_setoptions(a:ctx.winid, #{title: "[ " . a:title . " ]"})
endfunction


function! s:CalculateTextListDimensions(text_list)
    " calculate height. Half screen height or less
    let height = min([ (&lines-2) / 2, len(a:text_list) ])

    " calculate width. Somewhere between half and full screen width.
    let maxLine = max(map(copy(a:text_list), {i, v -> len(v)} ))
    let width = &columns - 4
    if maxLine < width
        if maxLine < (&columns / 2)
            let width = &columns / 2
        else
            let width = maxLine
        endif
    elseif len(a:text_list) > height
        " scrollbar
        let width -= 1
    endif
    return [height, width]
endfunction


" closes popup on any key
function! s:CloseFilter(id, key)
    if strchars(a:key) == 1
        call popup_close(a:id)
    endif
    return 1
endfunction

function! s:getctx(id)
    if popup_getpos(a:id) == {}
        throw "Popup with id " . a:id . " not found"
    endif

    let ctx =  getwinvar(a:id, "selector_ctx", {})
    if ctx == {}
        throw "Not a Selector popup: " . a:id
    endif
    return ctx
endfunction

" Popup callback, that calls the caller-provided callback
" with the parameters
" - popup context
" - key is '<SELECT>'
" - the selected item
function! s:PopupSelectorCallback(id, sel_idx)
    call remove(g:selector_popup_set, string(a:id))
    let ctx = s:getctx(a:id)

    if a:sel_idx < 1
        return
    endif

    let entry = s:GetLineEntry(ctx, a:sel_idx)

    call win_gotoid(ctx.caller_winid)
    call ctx.callback(a:id, ctx.options.user_data, "<SELECT>", entry.Item)
endfunction

function! s:GetLineEntry(ctx, line)
    return a:ctx.text_map[a:line - 1]
endfunction

"
" Shift popup text left/right
function! s:ShiftText(ctx, direction)

    if a:direction == '0'
        let a:ctx.start_col = 0
    elseif a:direction == '$'
        let ln = line('.', a:ctx.winid)
        let txt = s:GetLineEntry(a:ctx, ln).Item.Display
        let width = popup_getpos(a:ctx.winid)['core_width']
        let a:ctx.start_col = len(txt) - width
        if a:ctx.start_col < 0
            let a:ctx.start_col = 0
        endif
    elseif a:direction == 'l' || a:direction == "\<right>"
        let ln = line('.', a:ctx.winid)
        let txt = s:GetLineEntry(a:ctx, ln).Item.Display
        let width = popup_getpos(a:ctx.winid)['core_width']
        if (len(txt) - a:ctx.start_col) > width
            let a:ctx.start_col += 1
        endif
    elseif a:direction == 'h' || a:direction == "\<left>"
        if a:ctx.start_col > 0
            let a:ctx.start_col -= 1
        endif
    endif

    let text_list = []
    for entry in a:ctx.text_map
        call add(text_list, strpart(entry.Item.Display, a:ctx.start_col))
    endfor

    call popup_settext(a:ctx.winid, text_list)
endfunction

function! selectorpopup#UnHide(id)
    let ctx = s:getctx(a:id)
    call popup_show(ctx.winid)
endfunction

function! s:ToogleWrap(ctx)
    if popup_getoptions(a:ctx.winid).wrap == 1
        call popup_setoptions(a:ctx.winid, {'wrap':0})
    else
        let ln = line('.', a:ctx.winid)
        call popup_setoptions(a:ctx.winid, {'wrap':1})
        " the following doesn't work as expected
        call win_execute(a:ctx.winid, ln)
        redraw!
    endif
endfunction


"---------[ Character Handling ]-----------------------------------------------

function! s:PopupSelectorFilter(id, key)

    let ctx = s:getctx(a:id)
    if len(ctx.text_map) >= line('.', a:id)
        let entry = s:GetLineEntry(ctx, line('.', a:id))
        let entry_index = line('.', a:id) - 1
    else
        let entry = {}
        let entry_index = -1
    endif

    if ctx.filtering != v:false
        if a:key == "\n" || a:key == "\r"
            let ctx.filtering = v:false
            call s:EndFiltering(ctx)
        elseif a:key == "\<ESC>" || a:key == "\<C-C>"
            let ctx.filtering = v:false
            let ctx.filter_input = ""
            call s:EndFiltering(ctx)
        else
            call s:FilterInputChar(ctx, a:key)
        endif
        return 1
    endif

    let ln = line('.', a:id)

    " Handle double click like <CR>
    if a:key == "\<2-LeftMouse>" &&  s:GetMouseLine(ctx.winid) > 0
        let key = "\<CR>"
    else
        let key = a:key
    endif

    if selectorcore#CommonSelectorFilter(ctx, key, entry, entry_index) != 0
        return 1
    elseif key == "\<LeftMouse>"
        let mouseLine = s:GetMouseLine(ctx.winid)
        if mouseLine < 1
            " click on border or outside of popup -> let Vim handle that.
            return 0
        endif
        call win_execute(ctx.winid, "let curline = winline()")
        call win_execute(a:id, printf("%+d", (mouseLine - curline)))
        return 1
    elseif key == 'j' || key == "\<down>" || key == "\<ScrollWheelDown>"
        call popup_filter_menu(a:id, 'j')
    elseif key == 'k' || key == "\<up>" || key == "\<ScrollWheelUp>"
        call popup_filter_menu(a:id, 'k')
    elseif key == "\<C-F>" || key == "\<PageDown>"
        call win_execute(a:id, "normal \<C-F>" )
        if line("w$", a:id) == len(ctx.text_list)
            let cl = line(".", a:id)
            call win_execute(a:id, "normal " . len(ctx.text_list) . "zb" )
            call win_execute(a:id, ":" .. cl )
        endif
    elseif key == "\<C-B>" || key == "\<PageUp>"
        call win_execute(a:id, "normal \<C-B>" )
    elseif key == 'g'
        call win_execute(a:id, '1')
    elseif key == 'G'
        call win_execute(a:id, '$')
    elseif popup_getoptions(ctx.winid).wrap == 0 &&
                \ (key == 'l' || key == 'h' || key == '0' || key == '$'
                \ || key == "\<left>" || key == "\<right>")
        call s:ShiftText(ctx, key)
    elseif ctx.options.support_filter == v:true && key == '/'
        let ctx.filtering = v:true
        "let ctx.filter_input = ""
        call s:StartFiltering(ctx)
        " return 0
    elseif ctx.filter_input != "" && key == 'X'
        call s:ResetFilter(ctx)
    elseif index(s:MOUSE_KEYCODES, key) >= 0
        return 0
    endif
    return 1
endfunction

function! s:GetMouseLine(id)
    let mousepos = getmousepos()
    if mousepos.winid != a:id
        " Not in our window. Not our cup of tea.
        return 0
    endif

    let popup_info = popup_getpos(a:id)
    let popup_width = popup_info.width - (popup_info.scrollbar? 1: 0)
    echo printf("MouseCol: %d Width: %d", mousepos.wincol, popup_width)
    " mouse winrow includes border
    if mousepos.winrow <= 1 || mousepos.winrow >= popup_info.height
        " Upper or lower border
        return 0
    endif
    if mousepos.wincol <= 1 || mousepos.wincol > popup_width
        " Right or left border
        return 0
    endif
    return mousepos.winrow - 1
endfunction

"---------[ Filtering ]--------------------------------------------------------

if has("patch-8.2.2893")
    " This patch supports mbyte chars in popup titles
    const s:INPUT_CURSOR   = "\u2588"
else
    const s:INPUT_CURSOR   = "|"
endif
const s:INPUT_LABEL   = "FILTER: "

function! s:StartFiltering(ctx)
    "let a:ctx.filter_input = ''
    call selectorpopup#UpdateTitle(a:ctx, s:INPUT_LABEL . a:ctx.filter_input . s:INPUT_CURSOR)
endfunction

function! s:FilterInputChar(ctx, chr)
    if a:chr == "\<bs>"
        let a:ctx.filter_input = strcharpart(a:ctx.filter_input, 0, strlen(a:ctx.filter_input)-1)
    elseif a:chr == "\<C-W>"
        let a:ctx.filter_input = ""
    elseif strlen(strtrans(a:chr)) == 1
        let a:ctx.filter_input .= a:chr
    endif
    call selectorpopup#UpdateTitle(a:ctx, s:INPUT_LABEL . a:ctx.filter_input . s:INPUT_CURSOR)
    redraw!
    let [ text_list, text_map ] =  selectorcore#PopupEntryListFilter(a:ctx.entry_list, a:ctx.filter_input)
    let a:ctx.text_map = text_map
    call popup_settext(a:ctx.winid, text_list)

    if len(text_list) < popup_getpos(a:ctx.winid).core_height
        call win_execute(a:ctx.winid, "normal " . line("w0", a:ctx.winid) . "\<C-Y>")

    endif

    if a:ctx.filter_match_id >= 0
        call matchdelete(a:ctx.filter_match_id, a:ctx.winid)
        let a:ctx.filter_match_id = -1
    endif
    if a:ctx.filter_input != ""
        let a:ctx.filter_match_id  = matchadd('Search', '\c' . a:ctx.filter_input, 10, -1, {'window':a:ctx.winid})
    endif
endfunction

function! s:EndFiltering(ctx)
    if a:ctx.filter_input != ''
        call selectorpopup#UpdateTitle(a:ctx, a:ctx.title . " (filtered)")
    else
        call s:ResetFilter(a:ctx)
    endif
endfunction

function! s:ResetFilter(ctx)
    call selectorpopup#UpdateTitle(a:ctx, a:ctx.title)

    let a:ctx.filter_input = ''

    " save index of the item the cursor is on. Use -1 when empty
    "let item_idx = len(a:ctx.text_map) > 0 ? a:ctx.text_map[line('.', a:ctx.winid) - 1] : -1
    let current_entry = len(a:ctx.text_map) > 0 ? s:GetLineEntry(a:ctx, line('.', a:ctx.winid)) : {}

    let [ text_list, text_map ] =  selectorcore#PopupEntryListFilter(a:ctx.entry_list, "")
    let a:ctx.text_list = text_list
    let a:ctx.text_map = text_map
    if a:ctx.filter_match_id >= 0
        call matchdelete(a:ctx.filter_match_id, a:ctx.winid)
        let a:ctx.filter_match_id = -1
    endif
    call popup_settext(a:ctx.winid, text_list)

    let new_line = 1
    if current_entry != {}
        for e in text_map
            if e == current_entry
                break
            endif
            let new_line = new_line + 1
        endfor
    endif

    " set cursor on the saved item
    call win_execute(a:ctx.winid, new_line)
endfunction

function! s:GetSelectorPopupList(excl_id)
    let tlist = { 'list': [] }
    for [ k, id ] in items(g:selector_popup_set)
        if id == a:excl_id
            continue
        endif
        let opts = popup_getoptions(id)
        if len(opts) != 0
            call add(tlist.list, { 'Display': id . ": " . opts.title, 'popup': id })
        else
            call remove(g:selector_popup_set, k)
        endif
    endfor
    return tlist
endfunction

"---------[ List of Selector Popups ]------------------------------------------
function! selectorpopup#SelectorPopupsCallback(ctx, key, item)
    let opts = popup_getpos(a:item.popup)
    if a:key == '<SELECT>'
        if opts.visible == 0
            call selectorpopup#UnHide(a:item.popup)
        endif
    elseif a:key == 'c'
        call popup_close(a:item.popup)
        call selectorpopup#UpdateContent(a:ctx, s:GetSelectorPopupList(a:ctx.winid), 0)
    endif
endfunction

function! selectorpopup#SelectorPopups()

    let tlist = s:GetSelectorPopupList(-1)
    if len(tlist.list) == 0
        call popup_notification("No hidden Selectors found.", {})
        return
    elseif len(tlist.list) == 1
        call selectorpopup#SelectorPopupsCallback({}, '<SELECT>', tlist.list[0])
        return
    endif

    return selectorpopup#Selector("Popups", tlist, function("selectorpopup#SelectorPopupsCallback"), {
                \ 'select_help': 'unhide popup & close popup',
                \ 'mappings': [
                \ { 'key': 'c', 'help': 'close popup'},
                \ ]})

endfunction



"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
