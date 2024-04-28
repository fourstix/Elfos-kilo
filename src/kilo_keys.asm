; -------------------------------------------------------------------
; A simple full screen editor based on the Kilo editor, 
; a small text editor in less than 1K lines of code 
; written by Salvatore Sanfilippo aka antirez 
; available at https://github.com/antirez/kilo
; and described step-by-step at the website 
; https://viewsourcecode.org/snaptoken/kilo/index.html
; -------------------------------------------------------------------
; Also based on the Elf/OS edit program written by Michael H Riley
; available https://github.com/rileym65/Elf-Elfos-edit
; -------------------------------------------------------------------
; Copyright 2021 by Gaston Williams
; -------------------------------------------------------------------
; Based on software written by Michael H Riley
; Thanks to the author for making this code available.
; Original author copyright notice:
; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

#include include/ops.inc
#include include/bios.inc
#include include/kernel.inc
#include include/kilo_def.inc

; *******************************************************************
; ***                       Key Handlers                          ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: do_kilo
            ;
            ; Read a key and dispatch it to the appropriate 
            ; key handler until Ctrl+Q is pressed.
            ;-------------------------------------------------------       
            proc  do_kilo
            ; reads character until ctrl+q is typed  
c_loop:     call  o_readkey       ; get a keyvalue 
            str   r2              ; save char at M(X)
        
            ; Check for printable or control char
            ; values (0-31 or 127) control
        
chk_c:      ldi   27              ; check for escape char immediately
            sd                    ; if c = <esc>
            lbz   c_esc           ; process escape sequence
            ldi   ' '             ; check for bottom of printable char
            sd                    ; DF = 1, means space or higher
            lbnf  c_ctrl          ; jump if not printable
            smi   95              ; check for DEL
            lbz   c_ctrl          ; 127 is a control char
        
c_prt:      ldx                   ; get printable character at M(X)
            plo   r9
            
            push  rf              ; save rf
            push  r9              ; save r9 with character to type
            
            call  get_num_lines   ; set r9 to maximum line value

            sub16 r9, r8          ; is the current line in r8 at maximum?
            ghi   r9
            lbnz  cprt_mode       ; if r9 is not zero, continue on
            glo   r9
            lbnz  cprt_mode       ; if zero, current line is at maximum
            
            call  do_insline      ; insert a new line before typing
            call  put_line_buffer ; put new line in line buffer
            ldi   0               ; move to beginning column
            plo   rb
            
cprt_mode:  pop   r9              ; restore r9 with character to type
            load  rf, e_state     ; get editor state byte  
            ldn   rf
            ani   MODE_BIT        ; toggle input mode bit
            lbz   cprt_ins        ; default is insert mode
             
cprt_ovr:   call  do_typeover     ; overwrite printable character            
            lbr   cprt_done       
            
cprt_ins:   ghi   rb              ; get current line position
            smi   MAX_COL         ; check if at maximum
            lbdf  cprt_ovr        ; if at maximum, type over 
            call  do_typein       ; insert printable character            
cprt_done:  pop   rf              ; restore buffer register when done
            lbr   c_line          ; update line

                
c_esc:      call  o_readkey       ; get control sequence introducer character
            smi   '['             ; check for csi escape sequence
            lbnz  c_unkn          ; Anything but <Esc>[ is an unknown sequence
        
sq_csi:     call  o_readkey       ; get csi character
            stxd                  ; save character on stack
            smi   'A'             ; check for 3 character sequence
            lbdf  sq_ok           ; A and above are 3 character

            call  o_readkey       ; get closing ~ for 4 char sequence
            smi   '~'
            lbz   sq_ok           ; properly closed continue

            irx                   ; pop char from stack into D
            ldx 
            lbr   c_unkn          ; print unknown escape seq message
        
sq_ok:      irx                   ; get character from stack 
            ldx
            smi   49              ; check for <Esc>[1~ sequence
            lbz   c_home          ; process Home key
            smi   1               ; check for <Esc>[2~ sequence
            lbz   c_ins           ; process Insert key
            smi   1               ; check for <Esc>[3~ sequence
            lbz   c_del           ; process Delete key
            smi   1               ; check for <Esc>[4~ sequence
            lbz   c_end           ; process End key
            smi   1               ; check for <Esc>[5~ sequence
            lbz   c_pgup          ; process PgUp key
            smi   1               ; check for <Esc>[6~ sequence
            lbz   c_pgdn          ; process PgDn key
            smi   11              ; check for <Esc>[A
            lbnf  c_unkn          ; Unknown sequence
            lbz   c_up            ; process Up Arrow key
            smi   1               ; check for <Esc>[B
            lbz   c_dwn           ; process Down Arrow key
            smi   1               ; check for <Esc>[C
            lbz   c_rght          ; process Right Arrow key  
            smi   1               ; check for <Esc>[D
            lbz   c_left          ; process Left Arrow key
            smi   22              ; check for <Esc>[Z
            lbz   c_bktab         ; process Shift-Tab 
            lbr   c_unkn          ; Anything else is unknown
                
c_ctrl:     ldx                   ; get control character at M(X)
            smi   2               ; check for Ctrl-B (Home)
            lbz   c_home
            smi   1               ; check for Ctrl-C (Copy)
            lbz   c_copy
            smi   1               ; check for Ctrl-D (Down Arrow)
            lbz   c_dwn  
            smi   1               ; check for Ctrl-E (End)
            lbz   c_end  
            smi   1               ; check for Ctrl-F (Find)
            lbz   c_find
            smi   1               ; check for Ctrl-G (Go to Line)
            lbz   c_goto
            smi   1               ; check for Ctrl-H (Backspace)
            lbz   c_bs
            smi   1               ; check for Ctrl-I (Tab)
            lbz   c_tab
            smi   1               ; check for Ctrl-J (Join Line)
            lbz   c_join
            smi   1               ; check for Ctrl-K (Del)
            lbz   c_del
            smi   1               ; check for Ctrl-L (Left Arrow)
            lbz   c_left
            smi   1               ; check for Ctrl-M (Enter)
            lbz   c_enter
            smi   1               ; check for Ctrl-N (PgDn)
            lbz   c_pgdn
            smi   1               ; check for Ctrl-O (Overwrite/Insert)  
            lbz   c_ins
            smi   1               ; check for Ctrl-P (PgUp)
            lbz   c_pgup
            smi   1               ; check for Ctrl-Q (Quit)
            lbz   c_quit
            smi   1               ; check for Ctrl-R (Right Arrow)
            lbz   c_rght
            smi   1               ; check for Ctrl-S (Save)
            lbz   c_save
            smi   1               ; check for Ctrl-T (Top of File)
            lbz   c_top          
            smi   1               ; check for Ctrl-U (Up Arrow)
            lbz   c_up
            smi   1               ; check for Ctrl-V (Paste)
            lbz   c_paste
            smi   1               ; check for Ctrl-W (Where)
            lbz   c_where
            smi   1               ; check for Ctrl-X (Cut Line)
            lbz   c_cut        
            smi   1               ; check for Ctrl-Y (Save As)
            lbz   c_change
            smi   1               ; check for Ctrl-Z (End of File)
            lbz   c_bottom
            smi   2               ; check for Ctrl-\ (Split Line)
            lbz   c_split
            lbnf  c_unkn          ; Ctrl-[ is escape (used by ANSI sequences)
            smi   1               ; check for Ctrl-] (Back Tab)
            lbz   c_bktab
            smi   2               ; check for Ctrl-?
            lbz   c_help
            lbnf  c_unkn          ; Ctrl-^ is not used
            smi   96              ; check for DEL (Delete)            
            lbz   c_del
#ifdef  KILO_DEBUG
            ldx                 ; get char at M(X) 
            plo     rd          ; save character in         
            call    do_ctrl
#endif            
            lbr   c_loop          ; ignore any unknown chracters  

            ;----- Control key actions
c_bs:       call  do_backspace
            lbr   c_line
            
c_tab:      call  do_tab
            lbr   c_line
            
c_enter:    call  do_enter
            lbr   c_update

c_save:     call  do_save
            lbr   c_loop

c_change:   call do_change
            lbdf  c_chgskip
            call  do_save
c_chgskip:  lbr   c_loop

c_top:      call  do_top
            lbr   c_update

c_bottom:   call  do_bottom
            lbr   c_update

c_split:    call  do_split
            lbr   c_update

c_join:     call  do_join
            lbdf  c_loop          ; if unable to join, show error message
            lbr   c_update

c_quit:     call  do_quit         ; check dirty flag and prompt before quitting
            lbdf  c_loop          ; DF = 1, means don't quit 
            lbr   c_exit

            ;----- 4 character CSI escape sequences
c_home:     call  do_home
            lbr   c_update

c_ins:      push  rf              ; save register
            load  rf, e_state     ; get editor state byte  
            ldn   rf            
            xri   MODE_BIT        ; toggle input mode bit
            str   rf
            call  kilo_status     ; update status message
            call  prt_status
            call  get_cursor      ; restore cursor
            call  move_cursor     ; position cursor
            pop   rf              ; restore register
            lbr   c_loop
 
c_del:      call  do_del
            lbdf  c_update        ; if we deleted a line then update display
            lbr   c_line          ; otherwise just update line
             
c_end:      call  do_end
            lbr   c_update

c_pgup:     call  do_pgup
            lbr   c_update      

c_pgdn:     call  do_pgdn
            lbr   c_update

c_find:     call  do_find
            lbdf  c_update        ; if found, update display                   
            lbr   c_loop          ; otherwise, just continue
            
c_goto:     call  do_goto
            lbr   c_update        ; update display                   
            
c_where:    call  do_where        ; show file location line and column
            lbr   c_loop          ; continue processing                   

c_copy:     call  do_copy         ; copy a line into the clip board
            lbr   c_loop

c_paste:    call  do_paste        ; paste a line from the clip board
            lbr   c_update

c_cut:      call  do_copy         ; copy a line into the clip board
            call  do_kill         ; delete the current line
            lbr   c_update

#ifdef  KILO_DEBUG           
c_unkn:     call  o_type          ; show unknown character in D
            call  o_inmsg         ; indicate not terminated properly
              db    '<?>',0
            lbr   c_loop          ; continue processing                   
#else 
c_unkn:     lbr   c_loop          ; continue processing                   
#endif

#ifdef  KILO_HELP
c_help:     call  do_help         ; show help information
            lbr   c_update        ; refresh screen after help text
#else 
c_help:     lbr   c_loop          ; no help implemented
#endif
            
;-----  3 character csi escape sequences
c_up:       call  do_up
            lbr   c_update
            
c_dwn:      call  do_down            
            lbr   c_update

c_rght:     call  do_rght
            lbr   c_update


c_left:     call  do_left
            lbr   c_update

c_bktab:    call  do_bktab
            lbr   c_update

            ;---- check refresh flag and update screen or move cursor
c_update:   load  rf, e_state     ; check refresh bit
            ldn   rf
            ani   REFRESH_BIT     
            lbz   c_move          ; if no refrsh, just move cursor                        
c_redraw:   call  o_inmsg
              db 27,'[2J',0           ; erase display          
            call  refresh_screen
            lbr   c_loop    

c_move:     call  o_inmsg
              db 27,'[?25l',0     ; hide cursor
#ifdef KILO_DEBUG                  
            call  prt_status_dbg  ; update the status line              
#else            
            call  kilo_status     ; update the status message
            call  prt_status      ; update the status line              
#endif
            call  get_cursor
            call  move_cursor     ; move to new position
            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        
            lbr   c_loop

c_line:     call  refresh_line    ; update line on screen
            lbr   c_update
            
c_exit:     return            
            endp   
                           
            
            ;-------------------------------------------------------
            ; Name: do_home
            ;
            ; Handle the action when the Home key is pressed
            ; Parameters: 
            ;   rb.0 - current character position
            ; Uses: (None)
            ; Returns:
            ;   rb.0 - current character position
            ;-------------------------------------------------------                      
            proc  do_home
            ldi   0             ; set char position to far left
            plo   rb     
            call  scroll_left   ; update the cursor position
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_ins
            ;
            ; Handle the action when the Insert key is pressed
            ;-------------------------------------------------------                      
            proc  do_ins
            call    o_inmsg
              db 10,13,'<Insert>',0
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_del
            ; Handle the action when the Delete key is pressed
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ; Uses:
            ;  rd - destination pointer
            ; Returns:
            ;  DF = 0, line updated (refresh line)
            ;  DF = 1, line deleted (refresh screen)
            ;  rb.1 - updated line length
            ;-------------------------------------------------------                                  
            proc  do_del
            push  rf
            push  rd
            
            ghi   rb              ; get the line size
            lbz   del_line        ; delete line, if empty
            str   r2              ; save line size in M(X)
            glo   rb              ; get the current position
            sm                    ; subtract line size from char position
            lbdf  del_join        ; delete at end joins next line

            load  rf, line_buf    ; set pointer to line buffer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf              ; move to string

            glo   rb
            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add offset to buffer pointer
            plo   rf
            ghi   rf              ; get high byte of buffer
            adci   0              ; add carry into high byte
            phi   rf              ; rf points to character in buffer
            
            copy  rf, rd          ; set destination pointer to current location
            inc   rf              ; move buffer pointer to next byte

del_move:   lda   rf              ; get next character
            str   rd              ; copy into previous position in buffer
            inc   rd              ; move to next character
            lbnz  del_move        ; keep going until null copied
            
            ghi   rb              ; get the current line length
            smi   1               ; subtract one for deleted character
            phi   rb              ; update length
            
del_save:   load  rf, line_buf    ; set pointer to line buffer
            inc   rf              ; skip dirty byte
            call  update_line     ; update the line in text buffer
del_okay:   clc                   ; clear DF flag for line update
            lbr   del_exit
            
del_line:   load  rf, e_state
            ldn   rf
            ani   MODE_BIT
            lbnz  del_okay      ; in overwrite don't delete empty lines
            call  do_kill       ; delete the current line
            lbdf  del_okay      ; if no line deleted at end of file, just return
del_update: stc                 ; set DF flag for update
            lbr   del_exit
            
del_join:   load  rf, e_state
            ldn   rf
            ani   MODE_BIT
            lbnz  del_okay      ; in overwrite mode, don't join lines
            call  do_join
            lbr   del_update
               
del_exit:   pop   rd 
            pop   rf
            return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_end
            ;
            ; Handle the action when the End key is pressed
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ; Uses:
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                       
            proc  do_end
            ghi   rb            ; get the line length
            plo   rb            ; set character position to end of line
            call  scroll_right  ; update cursor position
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_pgup
            ;
            ; Handle the action when the Page Up key is pressed
            ; Parameters: (None) 
            ; Uses:
            ;   r9 - window size
            ;   r8 - current line
            ; Returns:
            ;   r8 - current line 
            ;-------------------------------------------------------                                  
            proc  do_pgup
            call  getcurln
            glo   r8                ; check for top of file
            lbnz  pup_cont          ; if r8 is non-zero, continue
            ghi   r8          
            lbz   pup_skip          ; if r8 = 0, then don't move up

pup_cont:   call  window_size       ; get the window dimensions
            ghi   r9                ; get the window size in rows
            smi   2                 ; subtract 1 for status line            
            str   r2                ; save rows in M(X)
            glo   r8                ; get low byte oftop line
            sm                      ; subtract row size from from top row
            plo   r8
            ghi   r8                ; adjust high byte for borrow
            smbi  0                 ; subtract borrow from hi byte
            phi   r8          
            lbdf  pup_ok            ; if positive, then top row is valid

            ldi   0                 ; if negative, set top row to zero
            phi   r8
            plo   r8 
pup_ok:     call  setcurln          ; save the current line
            call  find_line         ; get the current line
            ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  pup_size          ; if positive, set length
            ldi   0                 ; if negative, set length to zero
pup_size:   phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_up         ; set top row to new value
pup_skip:   return                  ; top row is new current row
            endp

            ;-------------------------------------------------------
            ; Name: do_pgdn
            ;
            ; Handle the action when the Page Down key is pressed
            ; Parameters: 
            ; Uses:
            ;   r9 - window size
            ;   r8 - current line
            ; Returns:
            ;   r8 - current line 
            ;-------------------------------------------------------                                  
            proc do_pgdn
            call  getcurln        ; get the current line
            call  window_size     ; get the window dimensions
            ghi   r9              ; get the window size in rows
            smi   1               ; subtract one for status line
            str   r2              ; save rows in M(X)
            glo   r8              ; get low byte of top line
            add                   ; add row size from to top row
            plo   r8
            ghi   r8              ; adjust high byte for carry
            adci  0               ; add carry to hi byte
            phi   r8
            call  find_line       ; check to see if line is valid
            lbnf  pdwn_ok         ; r8 is valid, so we are okay
            
            call  find_eob        ; otherwise find the end of buffer
            dec   r8              ; go back to last text line
            call  find_line       ; get the last line
pdwn_ok:    call  setcurln        ; set the new currentline
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  pdwn_size       
            ldi   0               ; if less than zero, set to zero
pdwn_size:  phi   rb              ; set line size for new line
            call  put_line_buffer ; put current line in line buffer
            call  scroll_down     ; calculate new row offset 
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_up
            ;
            ; Handle the action when the Up Arrow key is pressed
            ; Parameters:
            ;   r8 - current line number
            ; Uses: (None)
            ; Returns:
            ;   r8 - updated line number
            ;   rb.1 - new line size
            ;-------------------------------------------------------                                  
            proc  do_up
            glo   r8                ; check for top of file
            lbnz  up_cont           ; if r8 is non-zero, continue
            ghi   r8          
            lbz   up_skip           ; if r8 = 0, then don't move up
            
up_cont:    dec   r8                ; move current line up one
            call  setcurln          ; save current line in memory
            call  find_line         ; point ra to new line
            ldn   ra                ; get size of new line (including CRLF)
            smi   2                 ; adjust for one past last character
            lbdf  up_size           ; if positive, set the length
            ldi   0                 ; if negative, set length to zero
up_size:    phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_up         ; update row offset
up_skip:    return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_down
            ;
            ; Handle the action when the Down Arrow key is pressed
            ; Parameters:
            ;   r8 - current line number
            ; Uses:
            ;   r9 - number of rows in text buffer
            ; Returns:
            ;   r8 - updated line number
            ;-------------------------------------------------------                                  
            proc  do_down
            push  r9                  ; save scratch register
            call  get_num_lines       ; get the maximum lines
            call  getcurln            ; get current line
            sub16 r8,r9               ; check current line against limit
            lbdf  dwn_skip            ; if current line >= number lines, don't move                

            call  getcurln
            inc   r8                  ; move current line down one
            call  setcurln            ; save current line in memory
            call  find_line           ; point ra to new line
            ldn   ra                  ; get size of new line (including CRLF)
            smi   2                   ; adjust for one past last character
            lbdf  dwn_size            ; if positive set the length      
            ldi   0                   ; if negative, set length to zero
dwn_size:   phi   rb                  ; set rb.1 to new size
            call  put_line_buffer     ; put current line in line buffer
            call  scroll_down         ; update row offset
            
dwn_end:    pop   r9                  ; restore current line
            return

dwn_skip:   call  getcurln            ; restore r8 
            ldi   0                   
            phi   rb                  ; set length to zero
            plo   rb                  ; set current char position to zero
            lbr   dwn_end             ; and exit            
            endp

            ;-------------------------------------------------------
            ; Name: do_left
            ;
            ; Handle the action when the Left Arrow key is pressed
            ;
            ; Parameters:
            ;   rb.0 - current character position
            ; Uses: (None)
            ; Returns:
            ;   rb.0 - updated character position
            ;-------------------------------------------------------                                  
            proc  do_left
            glo   rb            ; get current character column
            lbz   lft_up        ; move up if at left-most column
            dec   rb            ; update character column
            call  scroll_left   ; scroll if needed, update cursor position
            lbr   lft_exit

lft_up:     glo   r8            ; check for top of file
            lbnz  lft_up2       ; if r8 is non-zero, continue
            ghi   r8          
            lbz   lft_exit      ; if r8 = 0, then don't move up

lft_up2:    ldi   MAX_LINE      ; set to one past maximum column position
            plo   rb            ; set char position to maximum
            call do_up          ; move up to end of previous line
lft_exit:   return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_rght
            ;
            ; Handle the action when the Right Arrow key is pressed
            ;
            ; Parameters:
            ;   rb.1 - line size
            ;   rb.0 - current character position
            ; Uses:
            ; Returns:
            ;   rb.0 - updated character position
            ;-------------------------------------------------------                                                
            proc do_rght
            ghi   rb            ; get the line size
            lbz   rght_exit     ; do nothing if empty line
            str   r2            ; save line size in M(X)
            glo   rb            ; get the current position
            sm                  ; subtract line size from char position
            lbdf  rght_dwn      ; move to beginning of next line
            inc   rb            ; otherwise increment char position
            call  scroll_right  ; scroll if needed, and adjust cursor              
rght_exit:  return
rght_dwn:   ldi   0             ; move to beginning column
            plo   rb
            call  do_down       ; move down to next line
            return              ; and exit
            endp


            ;-------------------------------------------------------
            ; Name: do_backspace
            ;
            ; Handle the action when the Backspace key is pressed
            ;-------------------------------------------------------                                                
            proc do_backspace
            glo   rb            ; get current character column
            lbz   bs_up         ; move up if at left-most column
            
            dec   rb            ; update character column
            call  do_del        ; delete character at new position
            call  scroll_left   ; scroll if needed, update cursor position
            lbr   bs_exit

bs_up:      glo   r8            ; check for top of file
            lbnz  bs_up2        ; if r8 is non-zero, continue
            ghi   r8          
            lbz   bs_exit       ; if r8 = 0, then don't move up

bs_up2:     ghi   rb            ; check line size
            lbnz  bs_up3        ; if non-zero, just move up to end of next line
            load  rf, e_state   ; get editor state
            ldn   rf    
            ani   MODE_BIT      ; check for insert or overwrite mode
            lbnz  bs_up3        ; in overwrite mode, don't delete the empty line
            call  do_kill       ; in insert mode, delete empty line
bs_up3:     ldi   MAX_LINE      ; set to one past maximum column position
            plo   rb            ; set char position to maximum
            call  do_up         ; move up to end of previous line

bs_exit:    return              ; for now do nothing at beginning of line
            endp


            ;-------------------------------------------------------
            ; Name: do_enter
            ;
            ; Handle the action when the Enter key is pressed
            ;-------------------------------------------------------                                                
            proc  do_enter
            push  rf            ; save register
            load  rf, e_state   ; get editor state
            ldn   rf    
            ani   MODE_BIT      ; check for insert or overwrite mode
            lbnz  ent_over      ; in overwrite mode, enter moves down to next line
            
            call  do_split      ; in insert mode, enter behaves like split line
            lbdf  ent_ins       ; if line was inserted, just exit
                        
ent_over:   call  do_down       ; move down to next line
ent_ins:    ldi   0             ; move to beginning column
            plo   rb
            pop   rf            ; restore registers
            return         
            endp

            ;-------------------------------------------------------
            ; Name: do_tab
            ; Handle the action when the Tab key is pressed
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ; Uses:
            ;  r9 - scratch register
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc do_tab
            push  r9              ; save scratch register
            glo   rb              ; get the current position
            adi   4               ; add 4 to move past current tab stop
            ani   $FC             ; mask sum to snap to next tab stop
            plo   r9              ; save in scratch register
            str   r2              ; save tab value in M(X)
            ghi   rb              ; get line length
            sm                    ; subtract next tab stop from column limit
            lbdf  tab_move        ; if (line length >= tab stop), just move cursor             
            ldi   MAX_COL         ; check with the maximum column position
            sm
            lbnf  tab_exit        ; don't move past maximum line length
            ghi   rb              ; get line length
            sd                    ; get difference (tab stop - length)
            call  pad_line        ; pad line with spaces to tab stop
            call  update_line     ; save padded line in buffer
tab_stop:   glo   r9              ; get tab stop
            str   r2              ; save tab stop at M(X)
tab_move:   ldx                   ; get next tab stop
            plo   rb              ; update cursor column
            call  scroll_right  
tab_exit:   pop   r9
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_bktab
            ; Handle the action when the Tab key is pressed
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ; Uses: (None)
            ; Returns:
            ;  rb.0 - updated character position
            ;-------------------------------------------------------                                                
            proc do_bktab
            glo   rb            ; get the character column value
            smi   1             ; subtract 1 to move before current tab stop
            lbnf  btab_end      ; if negative, ignore back tab
            ani   $FC           ; mask sum to snap to previous tab stop
            plo   rb            ; update character position
            call  scroll_left   ; update position 
btab_end:   return
            endp
            
            ;-------------------------------------------------------
            ; Name: do_save
            ;
            ; Save a file to the disk, if the file has changed.
            ; 
            ; Parameters: (None)
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   DF = 0, success (File saved or no changes to save)
            ;   DF = 1, an error occurred when saving the file
            ;-------------------------------------------------------                                                
            proc  do_save
            push  rf              ; save register
            call  is_dirty        ; DF = 1, means file is dirty    
            lbnf  ds_none         ; no changes to save
            
            call  save_buffer     ; save file to disk
            lbdf  ds_error        ; DF = 1, means an error occurred
            load  rf, saved_msg   ; show file was saved 
            ldi   0               ; save DF result on stack
            stxd    
            lbr   ds_show
            
ds_error:   load  rf, saved_err   ; show an error message
            ldi   1               ; save DF result on stack
            stxd
            lbr   ds_show

ds_none:    load  rf, clean_msg   ; set the status for unchanged file
            ldi   0
            stxd                  ; save DF result on stack
            
ds_show:    call  set_status      ; show message set previously
            call  prt_status      
            call  get_cursor      ; restore cursor after message
            call  move_cursor     ; position cursor 
            
            irx                   ; get DF value from stack
            ldx 
            shr                   ; Set DF 
            
            pop   rf              ; restore register 
            return
clean_msg:    db 'No file changes to save.',0
saved_msg:    db '*** File Saved. ***',0
saved_err:    db '*** ERROR Saving File. ***',0
            endp

            ;-------------------------------------------------------
            ; Name: do_top
            ;
            ; Handle the action when the Ctrl-T key is pressed
            ;-------------------------------------------------------                                                
            proc  do_top
            push  rf              ; save register used
            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            call  getcurln
            glo   r8                ; check for top of file
            lbnz  top_cont          ; if r8 is non-zero, continue
            ghi   r8          
            lbz   top_skip          ; if r8 = 0, then don't move up

top_cont:   ldi   0                 ; if negative, set top row to zero
            phi   r8
            plo   r8 
            call  set_row_offset    ; set row offset for the top of screen            
            call  setcurln          ; save the current line
            call  find_line         ; get the current line
            ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  top_size          ; if positive, set length
            ldi   0                 ; if negative, set length to zero
top_size:   phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            call  scroll_up         ; set top row to new value
top_skip:   ldi   0                 ; set char position to far left
            plo   rb     
            call  scroll_left       
            call  home_cursor       ; set cursor position for home
            pop   rf
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_bottom
            ;
            ; Handle the action when the Ctrl-T key is pressed
            ;-------------------------------------------------------                                                
            proc  do_bottom
            push  rf                ; save register used
          
            load  rf, e_state       ; set refresh bit
            ldn   rf                ; get editor state byte
            ori   REFRESH_BIT     
            str   rf
            
            call  get_num_lines     ; get total number of lines in r8
            dec   r9                ; line index is one less than number of lines
            copy  r9,r8             ; set current line to last line
            call  setcurln          ; save the current line
            call  find_line         ; get the current line
            ldn   ra                ; get size of current line
            smi   2                 ; adjust for one past last character
            lbdf  bot_size          ; if positive, set length
            ldi   0                 ; if negative, set length to zero
bot_size:   phi   rb                ; set rb.1 to new size
            call  put_line_buffer   ; put current line in line buffer
            ghi   rb                ; set char position to end of last line
            plo   rb  
            call  scroll_down       ; set top row to new value

            pop   rf
            return 
            endp
            
            ;-------------------------------------------------------
            ; Name: do_kill
            ;
            ; Delete a line. 
            ;-------------------------------------------------------                                                
            proc  do_kill
            push  rf              ; save registers used
            push  r9
            
            ;----- set r8 for current line
            call  getcurln
            call  is_eof          ; check if line index points to end of file
            lbdf  dk_skip         ; if line not deleted, skip update
            
            call  delete_line
            
            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf
            
            ;---- decrement total number of lines in the file
            call  dec_num_lines
            
dk_skip:    pop   r9
            pop   rf              
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_insline
            ;
            ; Handle the action when the Ctrl-Y key is pressed
            ;-------------------------------------------------------                                                
            proc  do_insline
            push  rf              ; save registers used
            
            ;----- set r8 for current line
            call  getcurln
          
            load  rf, ins_blank   ; set rf to insert blank line
            call  insert_line
          
            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            ;---- increment total number of lines in the file
            call  inc_num_lines
            
            pop   rf              ; restore registers
            return
ins_blank:    db 13,10,0            
            endp


            ;-------------------------------------------------------
            ; Name: do_copy
            ;
            ; Copy the current line of text to the clip board.
            ;
            ; Parameters: 
            ;   r8 - current line 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r8 - new current line
            ;-------------------------------------------------------                                                
            proc  do_copy
            push  rf              ; save registers used
            push  rd
            push  r8              ; save current line in case not found
            
            ;----- set r8 for current line
            call  getcurln
            call  find_line         ; get the current line of text
            ldn   ra                ; check size 
            lbz   dc_empty          ; if not found, just set to empty line
            
            call  put_line_buffer   ; put text in line buffer
            load  rf, line_buf + 1  ; skip over dirty flag
            load  rd, clip_brd      ; set rd to insert blank line
            
            call  f_strcpy          ; copy text string to clip board buffer

            load  rf, dc_copied     ; show not found message
            call  set_status        ; in the status bar
            call  prt_status      
            call  get_cursor        ; restore cursor after status message update
            call  move_cursor
            lbr   dc_exit
            
dc_empty:   ldi   0                 ; set null for empty string
            str   rd  
            
dc_exit:    pop   r8                ; restore registers
            pop   rd    
            pop   rf
            return
dc_copied:    db '*Line copied to clip board.*',0
            endp
            
            ;-------------------------------------------------------
            ; Name: do_paste
            ;
            ; Insert a line from the clip board before the current 
            ; line of text.
            ; Parameters: 
            ;   r8 - current line 
            ; Uses:
            ;   rf - buffer pointer
            ; Returns:
            ;   r8 - new current line
            ;-------------------------------------------------------                                                
            proc  do_paste
            push  rf              ; save registers used
            
            ;----- set r8 for current line
            call  getcurln
          
            load  rf, clip_brd    ; set rf to insert blank line
            call  insert_line
          
            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            ;---- increment total number of lines in the file
            call  inc_num_lines
            
            call  put_line_buffer ; put current line in line buffer
            ldi   0               ; move to beginning column
            plo   rb

            pop   rf              ; restore registers
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_split
            ;
            ; Split the current line into two lines.
            ; Parameters:
            ;   rb.1 - line length
            ;   rb.0 - character position
            ; Uses:
            ;   rf - buffer pointer
            ;   ra - pointer to line in text buffer
            ;   rc.0 - count of bytes
            ;   rc.1 - remaining count
            ; Returns:
            ;   DF = 1, line inserted (before or after)
            ;   DF = 0, line split in middle
            ;-------------------------------------------------------                                                
            proc  do_split
            ghi   rb              ; get the line size
            lbz   splt_after      ; insert line if empty line
            
            str   r2              ; save line size in M(X)
            glo   rb              ; get the current position
            lbz   splt_bfore      ; insert line before  
            sm                    ; subtract line size from char position
            lbdf  splt_after      ; insert line after
  
split_ln:   call  split_line
            call  setcurln        ; set the new current line
            call  find_line       ; set ra to the line in the text buffer
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  splt_size       ; if positive, update the size       
            ldi   0               ; if less than zero, set to zero
splt_size:  phi   rb 
            call  put_line_buffer ; put current line in line buffer
            ldi   0               ; move to beginning column
            plo   rb
            clc                   ; clear DF to indicate line split
            return 
        
splt_after: call  do_down         ; move down to next line
splt_bfore: call  do_insline
            call  put_line_buffer ; put current line in line buffer
            ldi   0               ; move to beginning column
            plo   rb              ; set character position to zero
            phi   rb              ; set line size to zero
            call  set_cursor      ; make sure cursor is updated
            stc                   ; set DF to indicate line inserted
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_tab
            ; Handle the action when the Tab key is pressed
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses: (None)
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_where
            push  rf              ; save registers
            push  rd
            
            call  getcurln        ; get current line index
            copy  r8, rd          ; copy index for conversion to ask        
            inc   rd              ; add one to index
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            
            load  rd, work_buf    ; set destination pointer to work buffer 
            load  rf, dw_lntxt    
dw_lnhdr:   lda   rf              ; copy line header into msg buffer
            lbz   dw_lnumbr         
            str   rd
            inc   rd
            lbr   dw_lnhdr
            
dw_lnumbr:  load  rf, num_buf     
dw_lnum:    lda   rf              ; copy line number into msg buffer
            lbz   dw_colmn        
            str   rd
            inc   rd
            lbr   dw_lnum

dw_colmn:   push  rd              ; save msg buffer pointer
            ldi   0               ; set up rd for converting column index
            phi   rd
            glo   rb              ; copy column index for conversion
            plo   rd
            inc   rd              ; add one to index
            load  rf, num_buf     ; put result in number buffer
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
              
            load  rf, dw_coltxt      
dw_clmn:    lda   rf              ; copy column label into msg buffer
            lbz   dw_cnumbr       ; then add column number
            str   rd
            inc   rd
            lbr   dw_clmn
            
dw_cnumbr:  load  rf, num_buf
dw_cnum:    lda   rf              ; copy column number into msg buffer
            lbz   dw_show
            str   rd
            inc   rd
            lbr   dw_cnum

dw_show:    ldi   0               ; make sure message ends in null
            str   rd
            load  rf, work_buf    ; show the location message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
                            
            pop   rd              ; restore registers
            pop   rf
            return
dw_lntxt:     db 'File Location at Line ',0
dw_coltxt:    db ' and Column ',0
            endp

            ;-------------------------------------------------------
            ; Name: do_goto
            ; Go to the line number entered by the user.
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses:
            ;  rc.0 - character limit
            ;  r9 - scratch register
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_goto
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               
            
            ldi   0               ; set up character count
            phi   rc
            ldi   MAX_INTSTR      ; up to 5 characters in integer (0 to 65536)
            plo   rc
            load  rf, dg_prmpt    ; set prompt to enter line number
            load  rd, work_buf    ; point to working buffer for input            
            call  do_input        ; prompt user for line number
            lbnf  dg_exit         ; if nothing entered, just exit
            
            copy  r8, r9          ; save original line index in r9
            load  rf, work_buf    ; convert string in work buffer to integer  
            call  f_atoi          ; convert ASCII string to integer in rd
            lbdf  dg_notfnd       ; DF = 1, means non-numeric string
            ghi   rd
            lbnz  dg_find
            glo   rd
            lbz   dg_notfnd       ; Zero is not a valid line number 
            
dg_find:    dec   rd              ; line index is one less than line number            
            copy  rd, r8          ; set line index to new falue
            call  find_line
            lbdf  dg_notfnd       ; DF = 1, means line not found in text buffer

            call  setcurln        ; save the current line
            ldn   ra              ; get size of new line (including CRLF)
            smi   2               ; adjust for one past last character
            lbdf  dg_size         ; if positive set the length      
            ldi   0               ; if negative, set length to zero
dg_size:    phi   rb              ; set rb.1 to new size
            call  put_line_buffer ; put current line in line buffer
            
            sub16 r8, r9          ; did we move up or down?            
            lbdf  dg_down         ; if new line > old line index, we went down
            
            call  getcurln        ; otherwise we went up, restore r8
            call  scroll_up       ; update row offset
            lbr   dg_exit         
            
dg_down:    call  getcurln        ; restore r8
            call  scroll_down     ; update row offset 
            lbr   dg_exit         
            
dg_notfnd:  copy  r9, r8          ; restore r8 to original value
            load  rf, dg_noline   ; show not found message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
            
dg_exit:    pop   r9
            pop   rc
            pop   rd
            pop   rf
            return 
dg_prmpt:     db 'Enter line number to go to: ',0
dg_noline:    db 'Line number not found.',0            
            endp 


            ;-------------------------------------------------------
            ; Name: do_change
            ; Change the filename to a new name entered by the user.
            ;
            ; Parameters:
            ; Uses:
            ;  rf - buffer pointer
            ;  rd - destination ptr
            ;  rc.0 - character limit
            ;  r9 - scratch register
            ; Returns:
            ;  DF = 0, name changed
            ;  DF = 1, name not changed
            ;-------------------------------------------------------                                                
            proc  do_change
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               
            
            ldi   0               ; set up character count
            phi   rc
            ldi   MAX_FNAME       ; up to 19 characters in filename
            plo   rc
            load  rf, dc_prmpt    ; set prompt to enter new file name
            load  rd, work_buf  ; point to working buffer for input            
            call  do_input        ; prompt user for line number
            lbnf  dc_badfn        ; if nothing entered, bad name
            
            load  rf, work_buf    ; validate name in working buffer
cd_chkfn:   lda   rf              ; get next character 
            lbz   dc_change       ; if reach end of string, valid name
            call  is_fnchar       ; is this a valid filename character?
            lbdf  cd_chkfn        ; DF =1, means valid, keep checking
            lbr   dc_badfn        ; otherwise, bad character in filename
            
dc_change:  load  rf, work_buf    ; source is new filename in work buffer 
            load  rd, fname       ; destination is fname buffer in kilo_file
            call  f_strcpy        ; copy new file name into fname buffer
            call  set_dirty       ; set the dirty flag to save with name change
            call  get_cursor      ; restore cursor after prompt message
            call  move_cursor
            clc                   ; Set DF = 0 for success
            lbr   dc_exit         ; and exit

dc_badfn:   load  rf, dc_invalid  ; show invalid file name message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
            stc                   ; DF = 1, means error

dc_exit:    pop   r9
            pop   rc
            pop   rd
            pop   rf
            return 
dc_prmpt:     db 'Enter new file name: ',0
dc_invalid:   db 'Invalid file name. File not saved.',0            
            endp 


            ;-------------------------------------------------------
            ; Name: do_find
            ; Find a string of text entered by the user.
            ;
            ; Parameters:
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses:
            ;  rc.0 - character limit
            ;  r9 - scratch register
            ; Returns:
            ;  DF = 1, string found
            ;  DF = 0, not found
            ;  r8   - updated line position
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_find
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               

            ldi   0               ; set up character count
            phi   rc
            ldi   MAX_TARGET      ; up to 40 characters in filename
            plo   rc
            load  rf, df_prmpt    ; set prompt to enter search string
            call  do_input        ; prompt user to enter string
            lbnf  df_nosrch       ; if nothing entered, don't do search
            
            load  rf, work_buf    ; set source string to input
            load  rd, df_target   ; point destination to target buffer            
            call  f_strcpy        ; copy string into target buffer
              
            copy  r8, r9          ; save current line in case not found
            glo   rb              ; get character position in case not found
            phi   rc              ; save character position in rc.1
            
            load  rd, df_target   ; make sure rd points to target

df_next:    call  find_string     ; find the string in buffer
            lbdf  df_found 

df_ask:     load  rf, df_redo     ; set prompt to try again
            call  do_confirm
            lbnf  df_none         ; if negative, don't search again
            ldi   0
            phi   r8              ; set current line to zero
            plo   r8
            plo   rb              ; set cursor position to Zero
            call  find_string     ; search from the top
            lbdf  df_found
            lbr   df_ask          ; show not found message
            
df_found:   load  rd, df_target   ; set destination to target string            
            call  found_screen    ; recalculate row and column offsets
                        
            call  o_inmsg
               db 27,'[2J',0      ; erase display and show found string        
            call  refresh_screen  ; r8, and rb.0 are set found string
            call  get_cursor      ; get the cursor
            call  move_cursor     ; position cursor at found string
            call  o_inmsg
              db 27,'[30;43m',0   ; set colors to black on yellow text
            load  rf, df_target   ; print target string over found text 
            call  o_msg           ; to highlight found string
            call  o_inmsg
              db  27,'[0m',0      ; set text back to normal     
            load  rf, df_again    ; set prompt to search again
            call  do_confirm
            lbnf  df_done         ; if negative, don't search again

            inc   rb              ; otherwise, move to next character position
            lbr   df_next         ; and search for next string occurence
                          
df_done:    load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            stc
            lbr   df_exit

df_none:    copy  r9, r8          ; restore current line
            ghi   rc              ; restore character position
            plo   rb
df_nosrch:  clc                   ; DF = 0, not found 
df_exit:    pop   r9
            pop   rc
            pop   rd
            pop   rf
            return 
df_prmpt:     db 'Enter text to find: ',0
df_again:     db 'Found. Search again (Y/N)?',0
df_redo:      db 'Not Found. Search again from the top (Y/N)?',0            
df_target:    ds MAX_TARGET+1             
              db 0
            endp 
            
            ;-------------------------------------------------------
            ; Name: do_join
            ;
            ; Join two lines into a single line.
            ;
            ; Parameters:
            ;   r8 - current line number
            ; Uses:
            ;   r9 - number lines above end of file
            ; Returns:
            ;   DF = 1, error (lines not joined)
            ;   DF = 0, success (lines joined)
            ;-------------------------------------------------------                                                
            proc do_join
            push  r9              ; save register used
            
            call  getcurln        ; make sure r8 is at current line
            call  is_eof          ; check if end of file, r9 has lines above eof
            lbdf  dj_none         ; nothing to join at eof, exit with DF set
            
            sub16 r9, 2           ; need at least two lines above eof, to join
            lbnf  dj_none         ; if less than 2 lines, don't join

            ghi   rb              ; check size of line
            lbnz  dj_join         ; if one or more characters, join with next line
            call  do_kill         ; if empty, just delete the line
            clc                   ; clear DF for success
            lbr   dj_exit       
                            
dj_join:    call  join_lines      ; attempt join the two lines
            lbdf  dj_err          ; if error, show message
            call  setcurln        ; set the new current line
            call  find_line       ; set ra to the line in the text buffer
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  dj_size       
            ldi   0               ; if less than zero, set to zero
dj_size:    phi   rb 
            call  put_line_buffer ; put joined line in buffer
            clc                   ; clear DF for success
            lbr   dj_exit
                   
dj_err:     load  rf, dj_long     ; if error, show status message
            call  set_status
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
dj_none:    stc                   ; set DF to indicate error
dj_exit:    pop   r9              ; restore register
            return
dj_long:       db '*Lines too long to join!*',0
            endp

            ;-------------------------------------------------------
            ; Name: do_typeover
            ; Type a printable character overwriting the existing
            ; character in the line
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ;  r9.0 - character to type
            ; Uses:
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc do_typeover
            push  rf
            load  rf, line_buf    ; set pointer to line buffer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf 

            glo   rb
            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add offset to buffer pointer
            plo   rf
            ghi   rf              ; get high byte of buffer
            adci   0              ; add carry into high byte
            phi   rf              ; rf points to character in buffer
            glo   r9              ; get character from scratch register
            str   rf              ; update character in buffer
            
            ghi   rb              ; get the current line length
            str   r2              ; save in M(X)
            glo   rb              ; check current cursor < line length
            sm                    ; did we write over eol bytes? (DF = 1 means yes)
            lbnf  to_done         ; if not, we are okay
            
            inc   rf              ; write CRLF,0 after last character
            ldi   13              ; write CR (13)
            str   rf
            inc   rf
            ldi   10              ; write LF (10)
            str   rf
            inc   rf
            ldi   0               ; write NULL
            str   rf
            
            ghi   rb              ; add one to line length
            adi   1
            phi   rb  

to_done:    glo   rb              ; check character position
            smi   MAX_COL         ; maximum column position
            lbdf  to_stay         ; if >= max, don't increment or move cursor
            inc   rb              ; move to next char position in line            
            call  scroll_right    ; scroll if needed, and adjust cursor              
            
to_stay:    load  rf, line_buf    ; set pointer to line buffer
            inc   rf              ; skip dirty byte
            call  update_line     ; update the line
to_exit:    pop   rf
            return
            endp  

            ;-------------------------------------------------------
            ; Name: do_typein
            ; Type a printable character inserting the character 
            ; into the line
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current cursor position
            ;  r9.0 - character to type
            ; Uses:
            ;  rf - buffer pointer
            ;  rd - destination pointer
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_typein
            push  rf              ; save registers
            push  rd
            
            load  rf, line_buf    ; set pointer to line buffer
            ldi   $FF             ; set dirty flag to true
            str   rf
            inc   rf 
            
            ;---- move buffer pointer to character position            
            glo   rb              ; get character position 
            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add offset to buffer pointer
            plo   rf
            ghi   rf              ; get high byte of buffer
            adci   0              ; add carry into high byte
            phi   rf              ; rf points to character in buffer
            copy  rf, rd          ; copy rf into destination pointer

            glo   rb              ; check character position
            smi   MAX_COL         ; with maximum column position
            lbdf  ti_stay         ; if past, don't insert, just overwrite
            
ti_fndend:  lda   rf              ; move rf to one past the end of string
            lbnz  ti_fndend
            
ti_shift:   str   rf              ; save value at one past original location
            dec   rf              ; move rf back to original location
            glo   rd              ; check if we moved last character
            str   r2              ; at rf = rd
            glo   rf
            sm                    ; if rf.0 != rd.0, continue moving characters
            lbnz  ti_cont
            
            ghi   rd              ; check high byte if low bytes are equal
            str   r2
            ghi   rf  
            sm
            lbz   ti_moved        ; if rd = rf, we are done moving characters
            
ti_cont:    dec   rf              ; back rf up to next character to move        
            lda   rf              ; load next character, and point to n+1
            lbr   ti_shift        ; continue shifting characters     
            
ti_moved:   glo   r9              ; get character from scratch register
            str   rd              ; insert character in buffer
                                  
            ghi   rb              ; add one to line length
            adi   1
            phi   rb  

            inc   rb              ; move to next char position in line            
            call  scroll_right    ; scroll if needed, and adjust cursor              
            lbr   ti_done
            
            ;---- if at the max column position don't update length or position
ti_stay:    glo   r9              ; get the new character
            str   rd              ; over write character at max column position
      
ti_done:    load  rf, line_buf    ; set pointer to line buffer
            inc   rf              ; skip dirty byte
            call  update_line     ; update the line
ti_exit:    pop   rd              ; restore registers
            pop   rf
            return
            endp  
            
; *******************************************************************
; ***                 Control Key Handlers                        ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: do_confirm
            ;
            ; Display a prompt and then read a key to check if 
            ; y or Y for a yes response was pressed.
            ; Parameters: (None) 
            ; Uses: 
            ;   rf - pointer to prompt string
            ; Returns: 
            ;   DF = 1, a 'Y' or 'y' was pressed
            ;   DF = 0, any other key was pressed      
            ;-------------------------------------------------------       
            proc  do_confirm        
            call  set_status
            call  prt_status      
                        
            call  o_readkey     ; get a keyvalue response 
            stxd                ; save char on stack
            call  kilo_status   ; restore status message
            call  prt_status    ; update status message
            call  get_cursor    ; restore cursor after questions
            call  move_cursor   ; position cursor
            irx                 ; get response from stack
            ldx 
            smi   'Y'           ; check for positive response
            lbz   dc_yes
            smi   $20           ; lower case letters are 32 characters from upper case
            lbz   dc_yes
            ldx                 ; get character again from M(X)
            smi   27            ; check for escape character (ANSI sequence)
            lbnz  dc_no 
            call  o_readkey     ; eat ansi sequences
            smi   '['           ; check for csi escape sequence
            lbnz  dc_no         ; Anything but <Esc>[ is not ANSI, so done
                    
            call  o_readkey     ; eat next character
            smi   'A'           ; check for 3 character sequence (arrows)
            lbdf  dc_no         ; A and above are 3 character, so we are done
            
            call  o_readkey     ; eat closing ~ for 4 char sequence (PgUp, PgDn, Home, End)
dc_no:      clc                 ; DF = 0, means No response
            lbr   dc_exit
dc_yes:     stc                 ; DF = 1, means Yes response
dc_exit:    return
            endp
            
            
            ;-------------------------------------------------------
            ; Name: do_input
            ;
            ; Display a prompt and read keys for user input 
            ; until a non-printable key or a limit is reached.
            ;
            ; Parameters: 
            ;   rf - pointer to prompt string
            ;   rc.0 - number of keys to read
            ; Uses: 
            ;   rd - destination buffer
            ; Returns: 
            ;   DF = 1, input entered
            ;   DF = 0, no input
            ;-------------------------------------------------------  
            proc  do_input                                
            push  rd            ; save registers
            
            load  rd, work_buf  ; set destination to working buffer
            ldi   0
            str   rd            ; set buffer to empty string
            
di_read:    call  set_input     ; show prompt with current input
            call  prt_status      

            call  o_readkey     ; get a key value response
            str   r2            ; save at M(X) 
            smi   32            ; check for control character (below space)
            lbnf  di_end
            ldx                 ; get character
            smi   127           ; check for DEL or non-ascii (above DEL)
            lbdf  di_end
            ldx                 ; get character
            str   rd            ; save in buffer
            inc   rd            ; save in buffer
            ldi   0             ; put null at end of input
            str   rd
            dec   rc            ; count down 
            glo   rc
            lbnz  di_read       ; keep going until count exhausted
            
di_end:     call  get_cursor    ; restore cursor after questions
            call  move_cursor   ; position cursor
            load  rd, work_buf  ; set buffer back to work buffer               
            ldn   rd            ; get first character
            lbz   di_none       ; if null, no input
            stc                 ; DF = 1, for input
            lbr   di_exit       
di_none:    clc                 ; DF = 0, for no input
di_exit:    pop   rd            ; restore register
            return
            endp



            ;-------------------------------------------------------
            ; Quit, check the dirty flag and confirm before exit.
            ; Parameters: (None) 
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: 
            ;   DF = 1, don't exit
            ;   DF = 0, exit the program      
            ;-------------------------------------------------------
            proc  do_quit
            push  rf              ; save register used
            call  is_dirty
            lbdf  dq_ask          ; if dirty, ask before exiting
            clc                   ; if not dirty, just say okay to exit  
            lbr   dq_exit
            
dq_ask:     load  rf, warn_str    ; set the status to the save file warning
            call  do_confirm      
            lbdf  dq_sure
            ldi   1               ; if no quit, exit with DF = 1
            stxd                  ; save No Quit DF value on stack
            lbr   dq_setdf        ; restore cursor after prompt

dq_sure:    load  rf, sure_str    ; make sure to quit without saving
            call  do_confirm
            lbdf  dq_yesquit      ; if confirmed twice, quit without saving     
            ldi   1               ; save No Quit DF Value on stack             
            stxd 
            lbr   dq_setdf
            
dq_yesquit: ldi   0               ; save Quit DF value on stack
            stxd 
dq_setdf:   irx                   ; get DF from stack
            ldx 
            shr                   ; shift value into DF
dq_exit:    pop   rf
            return

warn_str:     db 'Unsaved Changes!  Quit without Saving (Y/N)?', 0
sure_str:     db 'Are you sure (Y/N)?',0
            endp

#ifdef  KILO_HELP
            ;-------------------------------------------------------
            ; Name: do_help
            ;
            ; Show help information on screen
            ; Parameters: (None)
            ; Uses: 
            ;  rf - buffer pointer
            ; Returns: (None)
            ;-------------------------------------------------------                       
            proc  do_help
            push  rf              ; save register

            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf              ; refresh after showing help text

            call  o_inmsg
              db 27,'[?25l',0     ; hide cursor        

            call    o_inmsg       ; position cursor at 4,4
              db 27,'[4;0H',0
              
            call  o_inmsg
              db 27,'[30;43m',0   ; set colors to black on yellow text
              
            load  rf, hlp_txt1    ; print first line of text
            call  o_msg  

            load  rf, hlp_txt2    ; print next line of text
            call  o_msg  

            load  rf, hlp_txt3    ; print next line of text
            call  o_msg  

            load  rf, hlp_txt4    ; print next line of text
            call  o_msg  

            load  rf, hlp_txt5    ; print next line of text
            call  o_msg  

            load  rf, hlp_txt6    ; print last line of text
            call  o_msg  
            
            load  rf, hlp_prmpt

            call  do_confirm      ; prompt to dismiss
            clc                   ; clear DF after prompt
            
            call  o_inmsg
              db  27,'[0m',0      ; set text back to normal     

            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        
            pop   rf              ; restore register  
            return
            
hlp_txt1:     db '+--------------------------------+--------------------------------------+',13,10
              db '| ^B, Home   Beginning of line   | ^O, Ins     Overwrite/Insert Mode    |',13,10
              db '| ^C         Copy line           | ^P, PgUp    Previous Screen          |',13,10,0
hlp_txt2:     db '| ^D, Down   move cursor Down    | ^Q          Quit, if changed confirm |',13,10
              db '| ^E, End    End of line         | ^R, Right   move cursor Right        |',13,10
              db '| ^F         Find text string    | ^S          Save file                |',13,10,0
hlp_txt3:     db '| ^G         Go to line number   | ^T          Top of files             |',13,10
              db '| ^H, BS     Backspace           | ^U, Up      move cursor Up           |',13,10
              db '| ^I, Tab    move to next tab    | ^V          Paste line               |',13,10,0
hlp_txt4:     db '| ^J         Join lines          | ^W,         show Where in file       |',13,10
              db '| ^K, Del    delete character    | ^X          cut line into clip board |',13,10
              db '| ^L, Left   move cursor Left    | ^Y          save as new file         |',13,10,0
hlp_txt5:     db '| ^M, Enter  Insert mode, new    | ^Z          Bottom of File           |',13,10
              db '|   line or split. Overwrite     | ^\          Split line at cursor     |',13,10
              db '|   mode, move to next line      | ^], Shift+Tab  move to prevous tab   |',13,10,0
hlp_txt6:     db '| ^N, PgDn   Next screen         | ^?          Show this help text      |',13,10
              db '+--------------------------------+--------------------------------------+',13,10,0
hlp_prmpt:    db ' Press any key',0                            
            endp
            
#endif            
            
            
#ifdef  KILO_DEBUG
            ;-------------------------------------------------------
            ; Unknown Control key handler - print the hex value
            ; of the control key pressed.
            ; Parameters: 
            ;   rd.0 - control key value
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: (None)       
            ;-------------------------------------------------------
            proc  do_ctrl
            push    rf              ; save register used
            load    rf, hex_buf     ; point rf to hex buffer
            call    f_hexout2
        
            load    rf, hex_str     ; show string with hex value
            call    o_msg
            pop     rf              ; restore register
            return
            
hex_str:  db 10,13,'{'
hex_buf:  db 0,0
          db '}',0                        
            endp
#endif
