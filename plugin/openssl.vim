" openssl.vim version 3.3 2008 Noah Spurrier <noah@noah.org>
"
" == Changelog
"
" 3.3~fc1
"
"   • simple password safe can be either .auth.aes or .auth.bfa
"
" 3.3
"
"   • change simple password safe from .auth.bfa to .auth.aes
"
" == Edit OpenSSL encrypted files and turn Vim into a Password Safe! ==
"
" This plugin enables reading and writing of files encrypted using OpenSSL.
" The file must have the extension of one of the ciphers used by OpenSSL.
" For example:
"
"    .des3 .aes .bf .bfa .idea .cast .rc2 .rc4 .rc5
"
" This will turn off the swap file and the .viminfo log. The `openssl` command
" line tool must be in the path.
"
" == Install ==
"
" Put this in your plugin directory and Vim will automatically load it:
"
"    ~/.vim/plugin/openssl.vim
"
" You can start by editing an empty unencrypted file. Give it one of the
" extensions above. When you write the file you will be asked to give it a new
" password.
"
" == Simple Vim Password Safe ==
"
" If you edit any file named '.auth.aes' or '.auth.bfa' (that's the full name,
" not just the extension) then this plugin will add folding features and an
" automatic quit timeout.
"
" Vim will quit automatically after 5 minutes of no typing activity (unless
" the file has been changed).
"
" This plugin will fold on wiki-style headlines in the following format:
"
"     == This is a headline ==
"
" Any notes under the headline will be inside the fold until the next headline
" is reached. The SPACE key will toggle a fold open and closed. The q key will
" quit Vim. Create the following example file named ~/.auth.aes:
"
"     == Colo server ==
"
"     username: maryjane password: esydpm
"
"     == Office server ==
"
"     username: peter password: 4m4z1ng
"
" Then create this bash alias:
"
"     alias auth='view ~/.auth.aes'
"
" Now you can view your password safe by typing 'auth'. When Vim starts all
" the password information will be hidden under the headlines. To view the
" password information put the cursor on the headline and press SPACE. When
" you write an encrypted file a backup will automatically be made.
"
" This plugin can also make a backup of an encrypted file before writing
" changes. This helps guard against the situation where you may edit a file
" and write changes with the wrong password. You can still go back to the
" previous backup version. The backup file will have the same name as the
" original file with .bak before the original extension. For example:
"
"     .auth.aes  -->  .auth.bak.aes
"
" Backups are NOT made by default. To turn on backups put the following global
" definition in your .vimrc file:
"
"     let g:openssl_backup = 1
"
" Thanks to Tom Purl for the original des3 tip.
"
" I release all copyright claims. This code is in the public domain.
" Permission is granted to use, copy modify, distribute, and sell this
" software for any purpose. I make no guarantee about the suitability of this
" software for any purpose and I am not liable for any damages resulting from
" its use. Further, I am under no obligation to maintain or extend this
" software. It is provided on an 'as is' basis without any expressed or
" implied warranty.
"

augroup openssl_encrypted
if exists("openssl_encrypted_loaded")
    finish
endif
let openssl_encrypted_loaded = 1
autocmd!

function! s:OpenSSLReadPre()
    if has("filterpipe") != 1
        echo "Your systems sucks."
        exit 1
    endif
    set secure
    set cmdheight=3
    set viminfo=
    set clipboard=
    set noswapfile
    set noshelltemp
    set shell=/bin/sh
    set bin
    set shellredir=>
endfunction

function! s:OpenSSLReadPost()
    " Most file extensions can be used as the cipher name, but
    " a few  need a little cosmetic cleanup.
    let l:cipher = expand("%:e")
    let l:opts = "-pbkdf2 -salt"
    if l:cipher == "aes"
        let l:cipher = "aes-256-cbc"
        let l:opts = l:opts . " -a"
    endif
    if l:cipher == "bfa"
        let l:cipher = "bf"
        let l:opts = l:opts . " -a"
    endif
    let l:defaultopts = l:opts
    let l:expr = "0,$!openssl " . l:cipher . " " . l:opts . " -d -pass stdin -in " . expand("%")
    let l:defaultexpr = l:expr

    set undolevels=-1
    let l:a = inputsecret("Password: ")
    " Replace encrypted text with the password to be used for decryption.
    execute "0,$d"
    execute "normal i". l:a
    " Replace the password with the decrypted file.
    silent! execute l:expr
    let l:success = ! v:shell_error

    function! s:AttemptDecrypt(opts) closure
      if ! l:success
        execute "0,$d"
        execute "normal i". l:a
        let l:expr = "0,$!openssl " . l:cipher . " " . a:opts . " -d -pass stdin -in " . expand("%")
        " Replace the password with the decrypted file.
        silent! execute l:expr
        let l:success = ! v:shell_error
      endif
    endfunction

    " Be explicit about the current OpenSSL default of sha256.
    call s:AttemptDecrypt("-pbkdf2 -salt -a -md sha256")
    call s:AttemptDecrypt("-pbkdf2 -salt -md sha256")
    call s:AttemptDecrypt("-pbkdf2 -salt -a -md md5")
    call s:AttemptDecrypt("-pbkdf2 -salt -md md5")

    " The following is only ne
    if ! l:success
      " For the rest of these, might need to filter out the warning
      " about not using -pbkdf2, which looks like
      "     *** WARNING : deprecated key derivation used.
      "     Using -iter or -pbkdf2 would be better.
      let l:outputEncrypted = "2,$!cat " . expand("%")
      execute "0,$d"
      silent! execute "head -1 " . expand("%") . " | grep '^*** WARNING : deprecated key derivation used.$'"
      if ! v:shell_error
        let l:outputEncrypted = l:outputEncrypted . " | tail +3"
      endif
    endif

    function! s:AttemptDecryptWithFilter(opts) closure
      if ! l:success
        execute "0,$d"
        execute "normal i". l:a
        execute "normal o"
        silent! execute l:outputEncrypted
        let l:expr = "0,$!openssl " . l:cipher . " " . a:opts . " -d -pass stdin"
        " Replace the password and encrypted file with the decrypted file.
        silent! execute l:expr
        let l:success = ! v:shell_error
      endif
    endfunction

    call s:AttemptDecryptWithFilter("-salt -a -md sha256")
    call s:AttemptDecryptWithFilter("-salt -md sha256")
    call s:AttemptDecryptWithFilter("-salt -a -md md5")
    call s:AttemptDecryptWithFilter("-salt -md md5")
    " Don't bother with -nosalt and -md sha256 because those defaults
    " never existed together in OpenSSL.
    call s:AttemptDecryptWithFilter("-nosalt -a -md md5")
    call s:AttemptDecryptWithFilter("-nosalt -md md5")

    " Cleanup.
    let l:a="These are not the droids you're looking for."
    unlet l:a
    set nobin
    set cmdheight&
    set shellredir&
    set shell&
    redraw!
    if ! l:success
        silent! 0,$y
        silent! undo
        execute "0,$d"
        set undolevels&
        redraw!
        echohl ErrorMsg
        echo "ERROR -- COULD NOT DECRYPT"
        echo "You may have entered the wrong password or"
        echo "your version of openssl may not have the given"
        echo "cipher engine built-in. This may be true even if"
        echo "the cipher is documented in the openssl man pages."
        echo "DECRYPT EXPRESSION: " . l:defaultexpr
        echohl None
        throw "Unable to decrypt."
    endif
    execute ":doautocmd BufReadPost ".expand("%:r")
    set undolevels&
    redraw!
endfunction

function! s:OpenSSLWritePre()
    set cmdheight=3
    set shell=/bin/sh
    set bin
    set shellredir=>

    if !exists("g:openssl_backup")
        let g:openssl_backup=0
    endif
    if (g:openssl_backup)
        silent! execute '!cp % %:r.bak.%:e'
    endif

    " Most file extensions can be used as the cipher name, but
    " a few  need a little cosmetic cleanup. AES could be any flavor,
    " but I assume aes-256-cbc format with base64 ASCII encoding.
    let l:cipher = expand("<afile>:e")
    if l:cipher == "aes"
        let l:cipher = "aes-256-cbc -a"
    endif
    if l:cipher == "bfa"
        let l:cipher = "bf -a"
    endif
    let l:expr = "0,$!openssl " . l:cipher . " -e -salt -pass stdin"

    let l:a  = inputsecret("       New password: ")
    let l:ac = inputsecret("Retype new password: ")
    if l:a != l:ac
        let l:a ="These are not the droids you're looking for."
        let l:ac="These are not the droids you're looking for."
        echohl ErrorMsg
        echo "\n"
        echo "ERROR -- COULD NOT ENCRYPT"
        echo "The new password and the confirmation password did not match."
        echo "This file has not been saved."
        echo "ERROR -- COULD NOT ENCRYPT"
        echohl None
        " Clean up because OpenSSLWritePost won't get called.
        set nobin
        set shellredir&
        set shell&
        set cmdheight&
        throw "Password mismatch. This file has not been saved."
    endif
    silent! execute "0goto"
    silent! execute "normal i". l:a . "\n"
    silent! execute l:expr
    " Cleanup.
    let l:a ="These are not the droids you're looking for."
    let l:ac="These are not the droids you're looking for."
    redraw!
    if v:shell_error
        silent! 0,$y
        " Undo the encryption.
        call s:OpenSSLWritePost()
        echohl ErrorMsg
        echo "\n"
        echo "ERROR -- COULD NOT ENCRYPT"
        echo "Your version of openssl may not have the given"
        echo "cipher engine built-in. This may be true even if"
        echo "the cipher is documented in the openssl man pages."
        echo "ENCRYPT EXPRESSION: " . expr
        echo "ERROR FROM OPENSSL:"
        echo @"
        echo "ERROR -- COULD NOT ENCRYPT"
        echohl None
        throw "OpenSSL error. This file has not been saved."
    endif
endfunction

function! s:OpenSSLWritePost()
    " Undo the encryption.
    silent! undo
    set nobin
    set shellredir&
    set shell&
    set cmdheight&
    redraw!
endfunction

autocmd BufReadPre,FileReadPre     *.des3,*.des,*.bf,*.bfa,*.aes,*.idea,*.cast,*.rc2,*.rc4,*.rc5,*.desx call s:OpenSSLReadPre()
autocmd BufReadPost,FileReadPost   *.des3,*.des,*.bf,*.bfa,*.aes,*.idea,*.cast,*.rc2,*.rc4,*.rc5,*.desx call s:OpenSSLReadPost()
autocmd BufWritePre,FileWritePre   *.des3,*.des,*.bf,*.bfa,*.aes,*.idea,*.cast,*.rc2,*.rc4,*.rc5,*.desx call s:OpenSSLWritePre()
autocmd BufWritePost,FileWritePost *.des3,*.des,*.bf,*.bfa,*.aes,*.idea,*.cast,*.rc2,*.rc4,*.rc5,*.desx call s:OpenSSLWritePost()

"
" The following implements a simple password safe for any file named
" '.auth.aes' or '.auth.bfa'. The file is encrypted with AES and base64 ASCII
" encoded.  Folding is supported for == headlines == style lines.
"

function! HeadlineDelimiterExpression(lnum)
    if a:lnum == 1
        return ">1"
    endif
    return (getline(a:lnum)=~"^\\s*==.*==\\s*$") ? ">1" : "="
endfunction
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} set foldexpr=HeadlineDelimiterExpression(v:lnum)
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} set foldlevel=0
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} set foldcolumn=0
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} set foldmethod=expr
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} set foldtext=getline(v:foldstart)
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} nnoremap <silent><space> :exe 'silent! normal! za'.(foldlevel('.')?'':'l')<CR>
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} nnoremap <silent>q :q<CR>
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} highlight Folded ctermbg=red ctermfg=black
autocmd BufReadPost,FileReadPost   .auth.{aes,bfa} set updatetime=300000
autocmd CursorHold                 .auth.{aes,bfa} quit

" End of openssl_encrypted
augroup END

