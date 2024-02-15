
# Selector Library

This Vim plug-in provides a selector popup library. See
[doc/selector-lib.txt](doc/selector-lib.txt) for details.

A simple example that list the files in the current directory in a popup and
allows to open a file.

```
command! LS call SelectExample()

function! OpenFile(id, user_data, key, item)
  execute "edit " . a:item.Display
endfunction

function! SelectExample()
  let entry_list = selector#ListToSelectorList(systemlist('ls'))

  call selector#Selector("ls", entry_list, function("OpenFile"), #{
        \ select_help: 'open file & close selector',
        \ mappings: [#{ key: 'o', item: 1, help: 'open file' }]
        \ })
endfunction
```

## License

Copyright (c) Ralf Schandl.  Distributed under the same terms as Vim itself.
See `:help license` in Vim.
