"
" FILE: selector.vim
"
" ABSTRACT: generic selector interface
"
" AUTHOR: Ralf Schandl
"

" constant for window based selector
const selector#WINDOW = 'window'
" constant for popup based selector
const selector#POPUP = 'popup'

const selector#CB_RC_OK = 0
const selector#CB_RC_HIDE = 1
const selector#CB_RC_CLOSE = 2

const selector#POPUP_CENTER    = 'center'

const selector#POPUP_TOP       = 'top'
const selector#POPUP_TOP_LEFT  = 'top_left'
const selector#POPUP_TOP_RIGHT = 'top_right'

const selector#POPUP_BOT       = 'bot'
const selector#POPUP_BOT_LEFT  = 'bot_left'
const selector#POPUP_BOT_RIGHT = 'bot_right'

const selector#POPUP_AWAY      = 'away'
const selector#POPUP_CURSOR    = 'cursor'

function! selector#Selector(title, list, callback, options)

    let type = ""

    if selector#PopupSupported()
        let type = g:selector#POPUP
    else
        let type = g:selector#WINDOW
    endif

    if exists("g:SelectorForceType")
        if g:SelectorForceType == g:selector#POPUP || g:SelectorForceType == g:selector#WINDOW
            let type = g:SelectorForceType
        else
            throw "Selector: Invalid g:SelectorForceType: " . g:SelectorForceType
        endif
    endif

    if exists("a:options.type")
        if a:options.type == g:selector#POPUP || a:options.type == g:selector#WINDOW
            let type = a:options.type
        else
            throw "Selector: Invalid options.type: " . a:options.type
        endif
    endif

    if type == g:selector#POPUP
        return selectorpopup#Selector(a:title, a:list, a:callback, a:options)
    else
        return selectorwindow#Selector(a:title, a:list, a:callback, a:options)
    endif
endfunction

function! selector#PopupSupported()
    " Might work ok with a earlier version than 8.1.2188, but that's the
    " version I used for development.
    if v:version > 801
        return 1
    else if v:version == 801 && has("patch-8.1.2188")
        return 1
    else
        return 0
    endif
endfunction

function! selector#UpdateContent(id, list, line=0)
    let ctx =  s:GetSelectorCtx(a:id)
    if ctx.type == "popup"
        return selectorpopup#UpdateContent(ctx, a:list, a:line)
    elseif ctx.type == "window"
        return selectorwindow#UpdateContent(ctx, a:list, a:line)
    else
        throw "Selector: Invalid ctx"
    endif
endfunction

function! selector#UpdateTitle(id, title)
    let ctx =  s:GetSelectorCtx(a:id)
    if ctx.type == "popup"
        return selectorpopup#UpdateTitle(ctx, a:title)
    "elseif ctx.type == "window"
    "    return selectorwindow#UpdateContent(ctx, a:title)
    "else
    "    throw "Selector: Invalid ctx"
    endif
endfunction

function! selector#UnHide(id)
    let ctx =  s:GetSelectorCtx(a:id)
    if ctx.type == "popup"
        call selectorpopup#UnHide(a:id)
    "elseif ctx.type == "window"
    "    return selectorwindow#UpdateContent(ctx, a:title)
    "else
    "    throw "Selector: Invalid ctx"
    endif
endfunction

" Utility function to split a String into a list usable with
" selector#Selector.
" This function creates a list with a title and a lsit of dictionaries.
" Every dictionary contains the key "Display" with a part of the source
" string.
"
function! selector#StringToSelectorList(str, pattern)
    return selector#ListToSelectorList(split(a:str, a:pattern))
endfunc

function! selector#ListToSelectorList(list)
    return copy(a:list)->map({_, val -> {'Display': val}})
endfunction

function! s:GetSelectorCtx(id)
    let ctx =  getwinvar(a:id, "selector_ctx", {})
    if ctx == {}
        throw "Not a Selector popup or window: " . a:id
    endif
    return ctx
endfunction

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
