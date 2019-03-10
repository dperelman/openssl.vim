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
    let l:success = v:false
    while ! l:success
        silent! execute "0,$d _"
        redraw!
        if exists("l:a")
            echo " "
            echohl ErrorMsg
            echo "ERROR -- COULD NOT DECRYPT"
            echo "You may have entered the wrong password or"
            echo "your version of openssl may not have the given"
            echo "cipher engine built-in. This may be true even if"
            echo "the cipher is documented in the openssl man pages."
            echo "DECRYPT EXPRESSION: " . l:defaultexpr
            echohl WarningMsg
            echo " "
            echo "Try a different password or leave blank to cancel."
            echo " "
            echohl None
        endif
        let l:a = inputsecret("Password: ")

        " Replace encrypted text with the password to be used for decryption.
        execute "0,$d _"
        execute "normal i". l:a
        " Replace the password with the decrypted file.
        silent! execute l:expr
        let l:success = ! v:shell_error
        let b:OpenSSLDecryptSuccessful = l:success

        function! s:AttemptDecrypt(opts) closure
            if ! l:success
                execute "0,$d _"
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
            execute "0,$d _"
            silent! execute "head -1 " . expand("%") . " | grep '^*** WARNING : deprecated key derivation used.$'"
            if ! v:shell_error
                let l:outputEncrypted = l:outputEncrypted . " | tail +3"
            endif
        endif

        function! s:AttemptDecryptWithFilter(opts) closure
            if ! l:success
                execute "0,$d _"
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

        " Don't check for empty password before attempting to decrypt in
        " order to support decrypting with an empty password.
        if l:a == "" && ! l:success
            " Cleanup.
            set nobin
            set cmdheight&
            set shellredir&
            set shell&
            execute "0,$d _"
            set undolevels&
            redraw!
            throw "Empty password entered. Ending decryption attempts."
        endif

        let l:a="These are not the droids you're looking for."
    endwhile
    unlet l:a

    " Cleanup.
    set nobin
    set cmdheight&
    set shellredir&
    set shell&
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
        if filereadable(expand("%"))
            silent! execute '!cp % %:r.bak.%:e'
        endif
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
    let l:exprBase = "!openssl " . l:cipher . " -pbkdf2 -salt -pass stdin"
    let l:expr = "0,$" . l:exprBase . " -e"

    let l:shouldCheckPassword = (exists("b:OpenSSLDecryptSuccessful") && b:OpenSSLDecryptSuccessful)

    if ! l:shouldCheckPassword
        let l:a  = inputsecret("       New password: ")
    else
        let l:a  = inputsecret("           Password: ")
    endif
    if l:a == ""
        " Clean up because OpenSSLWritePost won't get called.
        set nobin
        set shellredir&
        set shell&
        set cmdheight&
        throw "Empty password. This file has not been saved."
    endif
    if ! l:shouldCheckPassword
        let l:ac = inputsecret("Retype new password: ")
    else
        " Attempt decrypting the existing file with the encryption
        " password to check if it's the same password.
        let l:decryptExpr = "1" . l:exprBase . " -d -in " . expand("%")
        silent! execute "0goto"
        silent! execute "normal i" . l:a . "\n"
        silent! execute l:decryptExpr . " >/dev/null 2>/dev/null"
        silent! undo
        if v:shell_error
            echohl WarningMsg
            echo " "
            echo "Warning: Password is different from decryption password."
            echo "If intending to change the encryption password, retype the new password."
            echo " "
            echohl None
            let l:ac = inputsecret("Retype new password: ")
        else
            let l:ac = l:a
        endif
    endif
    if l:a != l:ac
        let l:a ="These are not the droids you're looking for."
        unlet l:a
        let l:ac="These are not the droids you're looking for."
        unlet l:ac
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

    " Encrypt twice, first time take only the error output to capture it.
    " Then do the actual encryption.
    silent! execute "0goto"
    silent! execute "normal i". l:a . "\n"
    set shellredir=2>
    silent! execute l:expr . " 2>&1 >/dev/null"
    set shellredir=>
    " Backup @" register and restore it afterward.
    let l:register_tmp = getreg('"', 1, 1)
    let l:register_tmp_mode = getregtype('"')
    silent! 0,$y
    let l:openssl_error = @"
    call setreg('"', register_tmp, register_tmp_mode)
    unlet l:register_tmp
    unlet l:register_tmp_mode
    silent! undo

    silent! execute "0goto"
    silent! execute "normal i". l:a . "\n"
    silent! execute l:expr

    " Cleanup.
    let l:a ="These are not the droids you're looking for."
    unlet l:a
    let l:ac="These are not the droids you're looking for."
    unlet l:ac
    if v:shell_error
        " Something for OpenSSLWritePost() to undo
        silent! 0,$y _

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
        echo "\n"
        echo l:openssl_error
        echo "\n"
        echo "ERROR -- COULD NOT ENCRYPT"
        echohl None
        throw "OpenSSL error. This file has not been saved."
    endif
    if l:openssl_error !~ "^[\s\r\n]\*$"
        redraw!
        echohl WarningMsg
        echo "OpenSSL output the following warning:"
        echo " "
        echo l:openssl_error
        echo " "
        echo "This usually means openssl.vim needs to be updated or modified."
        echohl None
        echo "Press any key to continue..."
        let char = getchar()
        redraw!
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
    return (getline(a:lnum)=~"^\\s\\?\\*\\s.*$") || (getline(a:lnum)=~"^\\s*==.*==\\s*$") ? ">1" : "="
endfunction
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* set foldexpr=HeadlineDelimiterExpression(v:lnum)
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* set foldlevel=0
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* set foldcolumn=0
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* set foldmethod=expr
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* set foldtext=getline(v:foldstart)
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* nnoremap <silent><space> :exe 'silent! normal! za'.(foldlevel('.')?'':'l')<CR>
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* nnoremap <silent>q :q<CR>
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* highlight Folded ctermbg=red ctermfg=black
autocmd BufReadPost,FileReadPost   *.auth.*,logins.* set updatetime=300000
autocmd CursorHold                 *.auth.*,logins.* quit

" End of openssl_encrypted
augroup END

