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
; Copyright 2025 by Gaston Williams
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

            extrn   eol_msg

; *******************************************************************
; ***                       Key Handlers                          ***
; *******************************************************************

            ;-------------------------------------------------------
            ; Name: get_key
            ;
            ; Read a key from either directly from the bit-banged
            ; serial interface or from the hardware UART using a
            ; circular buffer.  
            ; 
            ; Parameters: 
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns:
            ;   D - character read
            ;-------------------------------------------------------       
.link  .align 128             
            proc  get_key
            
            ; ******************************************************************
            ; ***              Check if circular buffer in use               ***
            ; ******************************************************************
            load  rf, e_state     ; check key buffer bit in state byte
            ani   KBIO_BIT        ; zero out all but kbio bit
            lbz   o_readkey       ; delegate to kernel function if no buffer
            
            ; ******************************************************************
            ; ***  Read characters from the hardware serial UART port using  ***
            ; **   a circular buffer.  This routine is based on code written ***
            ; ***  by David Madole in his studio serial driver.  Available   ***
            ; ***  on GitHub: https://github.com/dmadole/Elfos-studio
            ; ******************************************************************            

gk_read:    call  f_utest         ; check for incoming serial character
            bnf  gk_get           ; if no more keys available, get key from buffer 
                     
            call  f_uread         ; get character
            plo   re              ; save key in scratch register
            
            ; ******************************************************************
            ; ***             Put character in circular buffer               ***
            ; ******************************************************************

            load  rf, keytail     ; set rf to tail pointer            
            lda   rf              ; get tail, move to head 
            adi   1               ; increment tail porter
            
            sdi   keypast.0       ; check if we went past end of the buffer
            bnz   gk_put          ; if we haven't reached the end we are good 
                                  
            ldi   KEY_BUF_SIZE    ; wrap around, keybuf.0 = keypast.0 - size                                            
                        
gk_put:     sdi   keypast.0       ; recover tail+1 value
            sex   rf              ; compare tail+1 to head
            sd                    ; if tail = head, then buffer is full
            bz    gk_get          ; if full, don't add any more 
            
            sd                    ; recover tail value
            sex   r2              ; make sure x = 2 for Elf/OS
            
            dec   rf              ; move back to tail ptr
            str   rf              ; store new value in tail
            plo   rf              ; set pointer to tail of buffer
            glo   re              ; get character read from serial
            str   rf              ; save in buffer
            
            ; br   gk_read         ; repeat until all keys are read into buffer
            call  f_utest         ; check for more serial character
            bdf   gk_read         ; if another came in, read into buffer
                        

            ; ******************************************************************
            ; ***            Get character from circular buffer              ***
            ; ******************************************************************
gk_get:     load  rf, keytail     ; set rf to tail pointer
            sex   rf              ; set x = rf for comparisons
            lda   rf              ; if head pointer is same as tail,
            xor                   ; then buffer is empty
            sex   r2              ; set x back to r2 
            bz    gk_read         ; if empty, read from serial
            
            ldn   rf              ; get head ptr
            adi   1               ; increment head pointer

            sdi   keypast.0       ; check if we went past the buffer
            bnz   gk_good         ; if we haven't reached the end we are good 
                      
            ldi   KEY_BUF_SIZE    ; wrap around, keybuf.0 = keypast.0 - size             
           
gk_good:    sdi   keypast.0       ; recover head value
            str   rf              ; update head pointer, then read
            plo   rf              ; the data byte the head pointer
            ldn   rf              ; points to as the character
            return
            
keytail:      db keybuf.0           ; end of circular buffer
keyhead:      db keybuf.0           ; beginning of circular buffer
keybuf:       db 0                  ; circular buffer starts here
              ds KEY_BUF_SIZE - 1   ; padding for rest of buffer entries
keypast:      db 0                  ; one byte past buffer end
              public  keytail
              public  keybuf
            endp   

            ;-------------------------------------------------------
            ; Name: flush_keys
            ;
            ; Read any keys available on the hardware UART and clear
            ; the circular buffer.  
            ; 
            ; Parameters: 
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: (none)
            ;   character read
            ;-------------------------------------------------------       
            proc  flush_keys
            load  rf, e_state     ; check if key buffer in use
            ani   KBIO_BIT        ; zero out all but key buffer io bit
            lbz   fk_exit         ; exit if no key buffer in use
            
fk_chk:     call  f_utest         ; check for incoming serial character
            bnf   fk_reset        ; if no more keys available, reset buffer 
                                 
            call  f_uread         ; get character
            lbr   fk_chk          ; keep going until no more incoming characters
                                    
fk_reset:   load  rf, keytail
            ldi   keybuf.0        ; reset head and tail to buffer beginning
            str   rf              ; reset keytail
            inc   rf
            str   rf              ; reset keyhead
            inc   rf
            ldi   0
            str   rf              ; reset key buffer data
            
fk_exit:    return            
            endp
                  
            ;-------------------------------------------------------
            ; Name: do_kilo
            ;
            ; Read a key and dispatch it to the appropriate 
            ; key handler until Ctrl+Q is pressed.
            ;-------------------------------------------------------       
            proc  do_kilo
      
            ; read characters until ctrl+q is typed  
c_loop:     call  get_key         ; get a keyvalue 
            
            ;----- move status message to just after 
            ;----- probably better to move to after each decode  
            stxd                  ; push character on stack
            
#ifndef KILO_DEBUG    
            load  rf, e_state     ; check refresh bit
            ldn   rf
            ani   STATUS_BIT      ; zero out all other bits, but status
            lbz   c_rdy           ; if no status update, ready to process character
            
            call  kilo_status     ; update the status message
            call  prt_status      ; update the status line
            call  get_cursor
            call  move_cursor

            load  rf, e_state     ; clear status bit after update
            ldn   rf
            ani   STATUS_MASK     ; clear bit
            str   rf              ; save updated editor state byte
                         
#endif
c_rdy:      irx                   ; pop character into D
            ldx                   ; char still at M(X)
        
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

            load  rf, c_rpt       ; get repeated character
            ldn   rf          
            sm                    ; check for match with repeat 
            lbz   c_rptd          ; if match, repeated char
            ldi   0               ; otherwise clear repeated char
            str   rf            
                        
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
            ani   ERROR_BIT       ; check for error
            lbnz   c_error        ; if error, exit with message    
            
            ldn   rf              ; get editor state byte again
            ani   MODE_BIT        ; toggle input mode bit
            lbz   cprt_ins        ; default is insert mode
             
cprt_ovr:   call  do_typeover     ; overwrite printable character            
            lbr   cprt_done       
            
cprt_ins:   glo   rb              ; get current line position
            smi   MAX_COL         ; check if at maximum
            lbdf  cprt_ovr        ; if at maximum, type over 
            call  do_typein       ; insert printable character            
cprt_done:  pop   rf              ; restore buffer register when done
            lbr   c_line          ; update line

c_rptd:     ldx                   ; get character and check for repeated arrows
            smi   'A'             ; check for ^[AAAA repeated sequence
            lbnf  c_unkn          ; anything below 'A' is unknown
            lbz   c_up            ; process Up Arrow key            
            smi   1               ; check for ^[BBBB
            lbz   c_dwn           ; process Down Arrow key
            smi   1               ; check for ^[CCCC
            lbz   c_rght          ; process Right Arrow key  
            smi   1               ; check for ^[DDDD
            lbz   c_left          ; process Left Arrow key
            lbnz  c_unkn          ; Anything else is an unknown sequence
                
c_esc:      load  rf, c_rpt       ; clear repeated character
            ldi   0               ; for control sequence
            str   rf
            call  get_key         ; get control sequence introducer character
           
            str   r2              ; save character at M(X)  
            smi   '['             ; check for csi escape sequence
            lbz   sq_csi          ; <Esc>[ is a valid ANSI sequence

            ldx                   ; get character and check for VT-52 sequences
            lbr   sq_vt52 
        
sq_csi:     call  get_key         ; get csi character
            
sq_vt52:    stxd                  ; save character on stack
            smi   'A'             ; check for 3 character sequence
            lbdf  sq_ok           ; A and above are 3 character sequences

            call  get_key         ; get closing ~ for 4 char sequence
            
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
            lbz   c_mode          ; process Insert key
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
                
c_ctrl:     load  rf, c_rpt       ; clear repeated character
            ldi   0               ; for control sequence
            str    rf
            ldx                   ; get control character at M(X)
            smi   2               ; check for Ctrl-B (Home)
            lbz   c_home
            lbnf  c_unkn          ; Ctrl-A (minicom), Ctrl-@ (null) are not used
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
            lbz   c_mode
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
            smi   2               ; check for Ctrl-^
            lbnf  c_unkn          ; Ctrl-^ is not used
            lbz   c_help          ; check for Ctrl-? (sometimes Ctrl-_)
            smi   96              ; check for DEL (Delete)            
            lbz   c_del

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

c_mode:     call  do_mode          ; toggle the editor mode
            lbr   c_loop
 
c_del:      call  do_del
            lbdf  c_update        ; if we deleted a line then update display
            lbr   c_line          ; otherwise just update line
             
c_end:      call  do_end
            lbr   c_update

c_pgup:     call  do_pgup

            load  rf, e_state     ; check for key buffer
            ani   KBIO_BIT        ; zero all but kbio bit
            lbz   cpup_nobuf       ; skip flush if no buffer in use
            call  flush_keys      ; flush the key buffer            

cpup_nobuf: lbr   c_update      

c_pgdn:     call  do_pgdn
            
            load  rf, e_state     ; check for key buffer
            ani   KBIO_BIT        ; zero all but kbio bit
            lbz   cpdn_nobuf       ; skip flush if no buffer in use
            call  flush_keys      ; flush the key buffer            
            
cpdn_nobuf: lbr   c_update

c_find:     call  do_find
            lbdf  c_update        ; if found, update display                   
            lbr   c_loop          ; otherwise, just continue
            
c_goto:     call  do_goto
            lbr   c_loop          ; continue processing                 
            
c_where:    call  do_where        ; show file location line and column
            lbr   c_loop          ; continue processing                   

c_copy:     call  do_copy         ; copy a line into the clip board
            lbr   c_loop

c_paste:    call  do_paste        ; paste a line from the clip board
            lbr   c_update

c_cut:      call  do_copy         ; copy a line into the clip board
            call  do_kill         ; delete the current line
            lbr   c_update

c_unkn:     lbr   c_loop          ; continue processing                   

#ifdef  KILO_HELP
c_help:     call  do_help         ; show help information
            lbr   c_update        ; refresh screen after help text
#else 
c_help:     lbr   c_loop          ; no help implemented
#endif
            
;-----  3 character csi escape sequences
c_up:       call  do_up
            load  rf, c_rpt       ; set repeated character
            ldi   'A'             ; for up arrow ^[AAAA
            str    rf
            lbr   c_update
            
c_dwn:      call  do_down  
            load  rf, c_rpt       ; set repeated character
            ldi   'B'             ; for down arrow ^[BBBB
            str    rf
            lbr   c_update

c_rght:     call  do_rght
            load  rf, c_rpt       ; set repeated character
            ldi   'C'             ; for right arrow ^[CCCC
            str    rf
            lbr   c_update

c_left:     call  do_left
            load  rf, c_rpt       ; set repeated character
            ldi   'D'             ; for left arrow ^[DDDD
            str    rf
            lbr   c_update

c_bktab:    call  do_bktab
            lbr   c_update

            ;---- check refresh flag and update screen or move cursor
c_update:   load  rf, e_state     ; check refresh bit
            ldn   rf              ; get state byte
            ani   ERROR_BIT       ; check for error
            lbnz   c_error        ; if error, show message and exit       

            ldn   rf              ; get state byte again
            ani   REFRESH_BIT     ; check for refresh
            lbz   c_move          ; if no refrsh, just move cursor                        
c_redraw:   call  refresh_screen
            lbr   c_loop    

c_move:     call  o_inmsg
              db 27,'[?25l',0     ; hide cursor
            call  o_inmsg         ; reset cursor for move
              db 27,'[H',0

            ;----- show debug message here before move  
#ifdef KILO_DEBUG                  
            call  prt_status_dbg  ; always show debug status line              
#endif

            call  get_cursor
            call  move_cursor     ; move to new position
            call  o_inmsg
              db 27,'[?25h',0     ; show cursor        
            lbr   c_loop

c_line:     call  refresh_line    ; update line on screen
            lbr   c_update

c_error:    load  rf, mem_err     ; show out of memory error
            call  do_confirm
              
c_exit:     return
c_rpt:        db 0                ; repeated character
mem_err:      db '*** An Error Occurred ***',0            
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
            ; Name: do_mode
            ;
            ; Toggle the editor mode, insert or overwrite
            ;
            ; Parameters: (None)
            ; Uses: 
            ;   rf - buffer pointer
            ; Returns: (None)
            ;-------------------------------------------------------                      
            proc  do_mode
            push  rf              ; save register
            load  rf, e_state     ; get editor state byte  
            ldn   rf            
            xri   MODE_BIT        ; toggle mode mode bit
            str   rf
            call  kilo_status     ; update status message for new mode
            call  prt_status
            call  get_cursor      ; restore cursor
            call  move_cursor     ; position cursor
            pop   rf              ; restore register
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
de_set:     plo   rb            ; set character position to end of line
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
            load  rf, line_buf      ; set pointer to line buffer
            lda   rf                ; check dirty byte, rf points to string
            lbz   pup_rdy           ; if no change in line, ready to scroll
            call  update_line       ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


pup_rdy:    call  getcurln
            glo   r8                ; check for top of file
            lbnz  pup_cont          ; if r8 is non-zero, continue
            ghi   r8          
            lbnz  pup_cont          ; if r8 is non-zero, continue

            ;-------------------------------------------------------                                  
            ; If at top of buffer, move to previous buffer  
            ;-------------------------------------------------------                                  
            call  prev_spill 
            lbdf  pup_skip          ; if no more buffers just skip
  
            call  clear_screen    ; clear the screen
            call  refresh_screen
            call  kilo_status       ; restore the normal status messae
            call  prt_status
            return                  ; if we loaded a new buffer we're done      

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
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   pdwn_rdy        ; if no change in line, ready to scroll
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


pdwn_rdy:   call  getcurln        ; get the current line
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

            ;-------------------------------------------------------                                  
            ; If bottom of buffer, move to next buffer  
            ;-------------------------------------------------------
            
            load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   pdwn_last       ; if no spill files, move to end
                                  
            call  next_spill      ; otherwise move to next spill file 
            lbdf  pdwn_last       ; if no more spill files, move to end
            
            call  o_inmsg
              db 27,'[2J',0       ; clear display

            call  refresh_screen  ; redraw screen
            call  kilo_status     ; restore the normal status messae
            call  prt_status
            return                ; if we loaded a new buffer we're done      
            
pdwn_last:  call  find_eob        ; otherwise find the end of current buffer
            dec   r8              ; go back to last text line
            call  find_line       ; get the last line
            lbdf  pdwn_exit       ; if not found, just exit            
            
pdwn_ok:    call  setcurln        ; set the new currentline
            ldn   ra              ; get the line size of new current line
            smi   2               ; subtract CRLF
            lbdf  pdwn_size       
            ldi   0               ; if less than zero, set to zero
pdwn_size:  phi   rb              ; set line size for new line
            call  put_line_buffer ; put current line in line buffer
            call  scroll_down     ; calculate new row offset 
pdwn_exit:  return
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
            load  rf, line_buf      ; set pointer to line buffer
            lda   rf                ; check dirty byte, rf points to string
            lbz   up_rdy            ; if no change in line, ready to move cursor
            call  update_line       ; update line in txt buffer
            dec   rf                ; clear dirty byte
            ldi   0                 ; in line buffer
            str   rf                ; after update


up_rdy:     glo   r8                ; check for top of file
            lbnz  up_cont           ; if r8 is non-zero, continue
            ghi   r8          
            lbnz  up_cont           ; if r8 is non-zero, continue

            ;-------------------------------------------------------                                  
            ; If at top of buffer, move to previous buffer  
            ;-------------------------------------------------------                                  
            call  prev_spill 
            lbdf  up_skip           ; if no more buffers just skip
  
            call  clear_screen      ; clear the screen
            call  refresh_screen
            call  kilo_status       ; restore the normal status messae
            call  prt_status
            return                  ; if we loaded a new buffer we're done      
            
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
            
            load  rf, line_buf        ; set pointer to line buffer
            lda   rf                  ; check dirty byte, rf points to string
            lbz   dwn_rdy             ; if no change, ready to move cursor
            call  update_line         ; update line in txt buffer
            dec   rf                  ; clear dirty byte
            ldi   0                   ; in line buffer
            str   rf                  ; after update

            
dwn_rdy:    call  get_num_lines       ; get the maximum lines
            call  getcurln            ; get current line
            sub16 r8,r9               ; check current line against limit
            lbnf  dwn_move            ; if current line < number lines, move down                
              
            ;-------------------------------------------------------                                  
            ; If bottom of buffer, move to next buffer  
            ;-------------------------------------------------------                        

            load  rf, spill_cnt       ; get the spill count
            ldn   rf        
            lbz   dwn_skip            ; if no spill files, don't move
                                  
            call  next_spill          ; otherwise move to next spill file 
            lbdf  dwn_skip            ; if no more spill files, don't move
            
            call  o_inmsg
              db 27,'[2J',0           ; clear display

            call  refresh_screen      ; redraw screen
            call  kilo_status         ; restore the normal status messae
            call  prt_status
            pop   r9                  ; restore scratch register
            return                    ; if we loaded a new buffer we're done      

dwn_move:   call  getcurln
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
            glo   rb
            smi   MAX_LINE      ; if at maximum column, move down
            lbdf  rght_dwn
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
            ldi   MAX_COL         ; check with the maximum column position
            sm
            lbnf  tab_exit        ; don't move past maximum line length
            ghi   rb              ; get line length
            sm                    ; subtract next tab stop from column limit
            lbdf  tab_move        ; if (line length >= tab stop), just move cursor             
            ghi   rb              ; get line length
            sd                    ; get difference (tab stop - length)
            call  pad_line        ; pad line with spaces to tab stop
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

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   ds_rdy          ; if no change in line, ready to save file
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


ds_rdy:     load  rf, saving_msg  ; show initial message
            call  set_status      ; show message set previously
            call  prt_status      
                        
            load  rf, e_state     ; get editor state byte  
            ldn   rf
            ani   DIRTY_BIT       ; check the dirty bit
            lbz   ds_none         ; no changes to save
            
            call  save_file       ; save file to disk
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
            
            load  rf, e_state     ; set status bit
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after file msg
            str   rf

            irx                   ; get DF value from stack
            ldx 
            shr                   ; Set DF 
            
            pop   rf              ; restore register 
            return
clean_msg:    db 'No file changes to save.',0
saved_msg:    db '* File Saved. *',0
saved_err:    db '* ERROR Saving File. *',0
saving_msg:   db 'Saving...',0
            endp

            ;-------------------------------------------------------
            ; Name: do_top
            ;
            ; Handle the action when the Ctrl-T key is pressed
            ;-------------------------------------------------------                                                
            proc  do_top
            push  rf              ; save register used

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   top_rdy         ; if no change in line, ready to move to top
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


top_rdy:    load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            call  getcurln
            glo   r8                ; check for top of file
            lbnz  top_cont          ; if r8 is non-zero, continue
            ghi   r8          
            lbnz  top_cont          ; if r8 is non-zero, continue

            ;-------------------------------------------------------                                  
            ; If at top of buffer, move to previous buffer  
            ;-------------------------------------------------------                                  
            call  prev_spill 
            lbdf  top_skip          ; if no more buffers just skip
  
            call  clear_screen    ; clear the screen
            call  refresh_screen
            call  kilo_status       ; restore the normal status messae
            call  prt_status
            pop   rf                ; restore register
            return                  ; if we loaded a new buffer we're done      

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
            ; Handle the action when the Ctrl-Z key is pressed
            ;-------------------------------------------------------                                                
            proc  do_bottom
            push  rf                ; save register used
          
            load  rf, line_buf      ; set pointer to line buffer
            lda   rf                ; check dirty byte, rf points to string
            lbz   db_rdy            ; if no change in line, ready to move to bottom
            call  update_line       ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


db_rdy:     load  rf, e_state       ; set refresh bit
            ldn   rf                ; get editor state byte
            ori   REFRESH_BIT     
            str   rf
            
            call  get_num_lines     ; get the maximum lines
            dec   r9                ; line index is one less than number of lines
            call  getcurln          ; get current line
            sub16 r8,r9             ; check current line against limit
            lbnf  db_move           ; if current line < number lines, just move down        
            
            ;-------------------------------------------------------                                  
            ; If bottom of buffer, move to next spill file  
            ;-------------------------------------------------------                                  
            call  next_spill 
            lbdf  db_exit           ; if no more spill files, don't move
  
            call  o_inmsg
              db 27,'[2J',0         ; erase display

            call  refresh_screen
            call  kilo_status       ; restore the normal status messae
            call  prt_status
            pop   rf                ; restore register
            return                  ; if we loaded a new buffer we're done      
        

db_move:    call  get_num_lines     ; get total number of lines in r8
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

db_exit:    pop   rf
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
            ;---  no need to save changes in line buffer if deleting line
            call  get_num_lines
            ghi   r9              ; check current count of lines
            lbnz  dk_cont         ; if non-zero continue on
            glo   r9              ; check low byte of count
            lbz   dk_skip         ; if no lines left, just quit
            
            ;----- set r8 for current line
dk_cont:    call  getcurln
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
      
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dins_rdy        ; if no change in line, ready to insert line
            call  update_line     ; update line in txt buffer
      
            ;----- set r8 for current line
dins_rdy:   call  getcurln
          
            load  rf, ins_blank   ; set rf to insert blank line
            call  insert_line
            lbdf  dins_err
          
            load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf

            ;---- increment total number of lines in the file
            call  inc_num_lines
            
dins_exit:  pop   rf              ; restore registers
            return
            
dins_err:   load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   ERROR_BIT       ; set error bit to exit     
            str   rf
            lbr   dins_exit       ; exit with status bit set
            
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
            
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dc_rdy          ; if no change in line, ready to copy
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


            ;----- set r8 for current line
dc_rdy:     call  getcurln
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

            load  rf, e_state     ; set status bit for update
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after eol msg
            str   rf

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

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dp_rdy          ; if no change in line, ready to paste
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


            ;----- set r8 for current line
dp_rdy:     call  getcurln
          
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
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   split_rdy       ; if no change in line, ready to split
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update

            
split_rdy:  ghi   rb              ; get the line size
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
            ; Name: do_where
            ; Show the character position in the file
            ;
            ; Parameters:
            ;  rb.1 - current line length
            ;  rb.0 - current character position
            ;  r8 -   current row
            ; Uses: 
            ;  r9 -   total number of lines
            ; Returns:
            ;  rb.0 - updated cursor position
            ;-------------------------------------------------------                                                
            proc  do_where
            push  rf              ; save registers
            push  rd
            push  r9
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dw_rdy          ; if no change in line, ready to show location
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


            
dw_rdy:     ldi   0               ; set up rd for converting column index
            phi   rd
            glo   rb              ; copy column index for conversion
            plo   rd
            inc   rd              ; add one to index
            load  rf, num_buf     ; put result in number buffer
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            
            load  rd, work_buf    ; set destination pointer to work buffer 
            load  rf, dw_coltxt    
dw_hdr:     lda   rf              ; copy column header into msg buffer
            lbz   dw_cnumbr         
            str   rd
            inc   rd
            lbr   dw_hdr

dw_cnumbr:  load  rf, num_buf
dw_cnum:    lda   rf              ; copy column number into msg buffer
            lbz   dw_sp_1         ; check for spill buffers
            str   rd
            inc   rd
            lbr   dw_cnum
            
dw_sp_1:    load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   dw_ln_sp        ; if no spill files, line separator
            
            load  rf, dw_bftxt      
dw_buf:     lda   rf              ; copy buffer label into msg buffer
            lbz   dw_bnumbr       ; then add buffer number
            str   rd
            inc   rd
            lbr   dw_buf

dw_bnumbr:  push  rd              ; save msg buffer pointer
            ldi   0               ; clear rd
            phi   rd
            load  rf, fbuf_idx    ; get the current buffer index
            ldn   rf                  
            plo   rd
            inc   rd              ; add one to index to get 1 based number
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
           
            load  rf, num_buf     
dw_bnum:    lda   rf              ; copy buffer number into msg buffer
            lbz   dw_row          ; add row lable to buffer message        
            str   rd
            inc   rd
            lbr   dw_bnum   

dw_row:     load  rf, dw_rwtxt      
dw_row2:    lda   rf              ; copy row label into msg buffer
            lbz   dw_rnumbr       ; then add row number
            str   rd
            inc   rd
            lbr   dw_row2

dw_rnumbr:  push  rd              ; save msg buffer pointer
            call  getcurln        ; get current line index
            copy  r8, rd          ; copy row index for conversion to ascii        
            inc   rd              ; add one to index to get 1 based number
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
            
            load  rf, num_buf     
dw_rnum:    lda   rf              ; copy row number into msg buffer
            lbz   dw_ln_sp2       ; end buffer message        
            str   rd
            inc   rd
            lbr   dw_rnum   

dw_ln_sp:   ldi   ','             ; if no buffers, separate with comma and space
            str   rd
            inc   rd
            ldi   ' '
            str   rd
            inc   rd 
            lbr   dw_ln           ; print the line number
            
dw_ln_sp2:  ldi   ' '             ; put space after row number
            str   rd
            inc   rd
            ldi   '('             ; and parenthesis to indicate computed line
            str   rd
            inc   rd

dw_ln:      load  rf, dw_lntxt      
dw_line:    lda   rf              ; copy line label into msg buffer
            lbz   dw_lnumbr       ; then add line number
            str   rd
            inc   rd
            lbr   dw_line

dw_lnumbr:  push  rd              ; save msg buffer pointer
            call  getcurln        ; get current line index
            copy  r8, r9          ; copy current line to convert to buffer value
            call  get_buf_line    ; convert to line value in buffer
            copy  r9, rd          ; copy index for conversion to ask        
            inc   rd              ; add one to index to get 1 based number
            load  rf, num_buf     
            call  f_uintout       ; convert to integer ascii string
            ldi   0               ; make sure null terminated
            str   rf              
            pop   rd              ; restore msg buffer pointer
            
            load  rf, num_buf     
dw_lnum:    lda   rf              ; copy line number into msg buffer
            lbz   dw_sp_2         ; check for spill buffera again        
            str   rd
            inc   rd
            lbr   dw_lnum   

dw_sp_2:    load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   dw_show         ; if no spill files, we are done

            
dw_bend:    ldi   ')'             ; close parenthesis after computed line number
            str   rd
            inc   rd
        
dw_show:    ldi   0               ; make sure message ends in null
            str   rd
            load  rf, work_buf    ; show the location message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; set status bit
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status after showing msg
            str   rf
            
            pop   r9              ; restore registers
            pop   rd
            pop   rf
            return
dw_coltxt:    db 'Column ',0
dw_lntxt:     db 'Line ',0
dw_bftxt:     db ', Buffer ',0
dw_rwtxt:     db ', Row ',0
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
            ;  DF = 0, success
            ;  DF = 1, error - invalid line number
            ;-------------------------------------------------------                                                
            proc  do_goto
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9               
            
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dg_rdy          ; if no change in line, ready to goto location
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


dg_rdy:     ldi   0               ; set up character count
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

            load  rf, spill_msg   ; show a message 
            call  set_status          
            call  prt_status          
            
            load  rf, spill_cnt   ; get the spill count
            ldn   rf        
            lbz   dg_text         ; if no spill files, search text buffer
            
            call  seek_buf_line   ; load buffer for line, set r8 to new line
            lbdf  dg_notfnd       ; DF = 1, means buffer index invalid
            lbr   dg_srch         ; find line in buffer
            
dg_text:    copy  rd, r8          ; set line index to new value

dg_srch:    call  find_line
            lbdf  dg_notfnd       ; DF = 1, means line not found in text buffer

            call  setcurln        ; save the current line
            ldn   ra              ; get size of new line (including CRLF)
            smi   2               ; adjust for one past last character
            lbdf  dg_size         ; if positive set the length      
            ldi   0               ; if negative, set length to zero
dg_size:    phi   rb              ; set rb.1 to new size
            call  put_line_buffer ; put current line in line buffer
            
            ldi   0               ; move to beginning column
            plo   rb

            sub16 r8, r9          ; did we move up or down?            
            lbdf  dg_down         ; if new line > old line index, we went down
            
            call  getcurln        ; otherwise we went up, restore r8
            call  scroll_up       ; update row offset
            lbr   dg_done         
            
dg_down:    call  getcurln        ; restore r8
            call  scroll_down     ; update row offset 
            lbr   dg_done        
            
dg_done:    call  clear_screen    ; clear screen
            call  refresh_screen  ; refresh screen
            call  kilo_status     ; set default status msg
            call  prt_status      ; restore status
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor
            clc                   ; set success 
            lbr   dg_exit         ; and exit
            
dg_notfnd:  copy  r9, r8          ; restore r8 to original value
            load  rf, dg_noline   ; show not found message
            call  set_status      ; in the status bar
            call  prt_status      
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; set status bit
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status after showing msg
            str   rf                                    
            stc                   ; set error
            
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

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   df_rdy          ; if no change in line, ready to find string
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


df_rdy:     ldi   0               ; set up character count
            phi   rc
            ldi   MAX_TARGET      ; up to 40 characters in target
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

            load  rf, spill_cnt   ; get the spill count
            ldn   rf
            lbnz  df_ask2        

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
            
            
df_ask2:    load  rf, df_nbuff    ; set prompt to try next buffer
            call  do_confirm
            lbnf  df_none         ; if negative, don't search again
            
            call  next_spill
            lbnf  df_nbsrch       ; if next buffer available, search it
            
            load  rf, df_redo     ; ask if we want to reset to top
            call  do_confirm
            lbnf  df_none         ; if negative, don't search again
            
            call  reset_spill     ; reset to first spill file
            
df_nbsrch:  ldi   0               
            phi   r8              ; set current line to zero
            plo   r8
            plo   rb              ; set cursor position to Zero
            plo   r9              ; clear saved position
            phi   r9
            phi   rc
            call  clear_screen    ; clear screen
            call  refresh_screen  ; r8, and rb.0 are reset
            
            call  find_string     ; search from the top
            lbdf  df_found
            lbr   df_ask2         ; show not found message
            
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
df_nbuff:     db 'Not Found. Search next buffer (Y/N)?',0            
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
            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dj_rdy          ; if no change in line, ready to paste
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update

      
dj_rdy:     call  getcurln        ; make sure r8 is at current line
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
            
            load  rf, e_state     ; set status bit in editor state
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after error msg
            str   rf
            
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
            glo   rb              ; check character position
            smi   MAX_LINE        ; check if one past max column
            lbdf  to_stay         ; if past, don't type anything

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
            
            ghi   rb              ; check line length
            smi   MAX_LINE        ; for max length
            lbdf  to_done         ; don't go past maximum
            
            ghi   rb              ; otherwise add one to line length
            adi   1
            phi   rb  

to_done:    glo   rb              ; check character position
            smi   MAX_COL         ; maximum column position
            lbdf  to_stay         ; if >= max, don't increment or move cursor

            inc   rb              ; move to next char position in line            
            call  scroll_right    ; scroll if needed, and adjust cursor              
            lbr   to_exit         
            
to_stay:    load  rf, eol_msg     ; show max line size message
            call  set_status
            call  prt_status
            call  get_cursor      ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; set status bit for update
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after eol msg
            str   rf

to_exit:    pop   rf
            return
              ; Warning message for when line length reaches limit 
eol_msg:      db  '* Maximum Line Length *',0
            public eol_msg
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

            ghi   rb              ; check line length
            smi   MAX_LINE        ; with maximum line length
            lbdf  ti_skip         ; if at limit, don't insert more characters

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
            lbr   ti_exit
            
            ;---- if at the max column position or max length don't insert 
ti_skip:    load  rf, eol_msg     ; show max line size warning message
            call  set_status
            call  prt_status
            call  get_cursor        ; restore cursor after status message update
            call  move_cursor

            load  rf, e_state     ; set status bit for update
            ldn   rf
            ori   STATUS_BIT      ; set bit to reset status msg after eol msg
            str   rf
            
            call  do_typeover     ; instead type over 
            
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
                        
            call  get_key       ; get a keyvalue response
            
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
            
            call  get_key       ; eat ansi sequences
            
            smi   '['           ; check for csi escape sequence
            lbnz  dc_no         ; Anything but <Esc>[ is not ANSI, so done
                    
            call  get_key       ; eat next character
            
            smi   'A'           ; check for 3 character sequence (arrows)
            lbdf  dc_no         ; A and above are 3 character, so we are done
            
            call  get_key       ; eat closing ~ for 4 char sequence (PgUp, PgDn, Home, End)

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
            push  rb
            
            copy  rf, rb        ; save copy of pointer to input message
            load  rd, work_buf  ; set destination to working buffer
            ldi   0
            str   rd            ; set buffer to empty string
            
di_read:    copy  rb, rf        ; restore input prompt from copy
            call  set_input     ; show prompt with current input
            call  prt_status      

            call  get_key       ; get a key value response

            
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
                   
di_none:    load  rf, e_state   ; restore status msg after no input
            ldn   rf
            ori   STATUS_BIT    ; set bit for status msg update
            str   rf
            clc                 ; DF = 0, for no input
di_exit:    pop   rb            ; restore registers
            pop   rd
            return
            endp

            ;-------------------------------------------------------
            ; Name: do_quit
            ;
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

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dq_rdy          ; if no change in line, ready to quit
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


dq_rdy:     load  rf, e_state     ; get editor state byte  
            ldn   rf
            ani   DIRTY_BIT       ; check the dirty bit
            lbnz  dq_ask          ; if changes, ask before exit

            clc                   ; if not dirty, just exit  
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

            load  rf, line_buf    ; set pointer to line buffer
            lda   rf              ; check dirty byte, rf points to string
            lbz   dh_rdy          ; if no change in line, ready to show help
            call  update_line     ; update line in txt buffer
            dec   rf              ; clear dirty byte
            ldi   0               ; in line buffer
            str   rf              ; after update


dh_rdy:     load  rf, e_state     ; set refresh bit
            ldn   rf              ; get editor state byte
            ori   REFRESH_BIT     
            str   rf              ; refresh after showing help text

            call  o_inmsg
              db 27,'[?25l',0     ; hide cursor        

            call  o_inmsg       ; position cursor at 4,4
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

            load  rf, hlp_txt6    ; print next line of text
            call  o_msg  
            
            load  rf, hlp_prmpt

            call  do_confirm      ; prompt to dismiss
            clc                   ; clear DF after prompt
            
            call  o_inmsg
              db  27,'[0m',0      ; set text back to normal     
            call  o_inmsg
            db 27,'[?25h',0     ; show cursor        

            call  clear_screen     
            call  refresh_screen  ; redraw screen
            call  kilo_status     ; update the status message
            call  prt_status      ; update the status line  
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
hlp_txt6:     db '| ^N, PgDn   Next screen         | ^?, ^_      Show this help screen    |',13,10
              db '+--------------------------------+--------------------------------------+',13,10,0
hlp_prmpt:    db ' Press any key',0                            
            endp
            
#endif            
