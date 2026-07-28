vim9script

if exists('g:v9_hs_uuid2c')
  finish
endif
g:v9_hs_uuid2c = 1

# Internal plug mappings passing specific style strings
nnoremap <Plug>(GenerateUUIDC) <scriptcmd>v9_hs_uuid2c#GenerateUUID(v:count1, 'c_array')<CR>
nnoremap <Plug>(GenerateUUIDRCPR) <scriptcmd>v9_hs_uuid2c#GenerateUUID(v:count1, 'rcpr')<CR>
nnoremap <Plug>(GenerateUUIDJava) <scriptcmd>v9_hs_uuid2c#GenerateUUID(v:count1, 'java')<CR>

# Default leader mappings
nmap <leader>guc <Plug>(GenerateUUIDC)
nmap <leader>gur <Plug>(GenerateUUIDRCPR)
nmap <leader>guj <Plug>(GenerateUUIDJava)

# Command interface with optional style argument
command! -count=1 -nargs=? GenerateUUID v9_hs_uuid2c#GenerateUUID(<count>, empty(<q-args>) ? 'c_array' : <q-args>)
