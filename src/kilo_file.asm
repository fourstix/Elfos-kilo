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

            extrn   textbuf
            extrn   curline
            extrn   fildes
            extrn   k_dta
            extrn   readln
            extrn   readbyte
            extrn   k_char
            
            ;-------------------------------------------------------
            ; Name: find_eob
            ;
            ; Find the end of the text buffer
            ;
            ; Returns: 
            ;   r8 - Line number     
            ;   ra - pointer to line at end of buffer
            ;-------------------------------------------------------       
            proc  find_eob   
            load  ra, textbuf
            ldi   0             ; setup count
            phi   r8
            plo   r8
            
feob_lp:    lda   ra            ; get count
            lbz   feob_done     ; jump if end was found
            str   r2
            glo   ra
            add
            plo   ra
            ghi   ra
            adci  0
            phi   ra
            inc   r8            ; increment line count
            lbr   feob_lp
feob_done:  dec   ra            ; move back to end of buffer byte
            return              ; and return
            endp

            ;-------------------------------------------------------
            ; Name: setcurln
            ;
            ; Set current line to specified value            
            ; Parameters: 
            ;   r8 - line number to set as current
            ; Uses:
            ;   rf - pointer to current line byte
            ; Returns: (None)
            ;-------------------------------------------------------       
            proc  setcurln
            push  rf            ; save consumed register
            load  rf, curline   ; point to current line
            ghi   r8            ; write new current line
            str   rf
            inc   rf
            glo   r8
            str   rf
            pop   rf            ; recover consumed register
            return              ; and return
            endp

            ;-------------------------------------------------------
            ; Name: getcurln
            ;
            ; Get the current line number            
            ; Parameters: (None) 
            ; Uses:
            ;   rf - pointer to current line byte
            ; Returns:
            ;   r8 - line number to set as current
            ;-------------------------------------------------------       
            proc  getcurln
            push  rf            ; save consumed register
            load  rf,curline    ; point to current line
            lda   rf            ; get current line number
            phi   r8
            lda   rf
            plo   r8
            pop   rf            ; restore register
            return              ; and return
            endp
                       
; *************************************
; *** Find line in text buffer      ***
; *** R8 - line number              ***
; *** Returns: RA - pointer to line ***
; *************************************
            ;-------------------------------------------------------
            ; Name: find_line
            ;
            ; Set current line to specified value            
            ; Parameters: 
            ;   r8 - line number to find
            ; Uses:
            ;   rc - counter for lines
            ; Returns: 
            ;   DF = 0, if found
            ;   DF = 1, if not found
            ;   ra - pointer to line in buffer
            ;-------------------------------------------------------       
            proc  find_line
            push  rc            ; save consumed regsiter
            load  ra, textbuf   ; point to text buffer
            ghi     r8          ; get line number
            phi     rc
            glo     r8
            plo     rc
findlp:     ghi     rc
            lbnz    notfound
            glo     rc          ; see if count is zero
            lbz     found       ; jump if there
notfound:   lda     ra
            lbz     fnderr      ; jump if end of buffer was reached
            str     r2          ; prepare for add
            glo     ra          ; add to address
            add
            plo     ra
            ghi     ra
            adci    0
            phi     ra
            dec     rc          ; decrement count
            lbr     findlp      ; and check line
found:      ldi     0           ; signal line found
            shr
            lbr     fnd_done    ; and return to caller
fnderr:     dec     ra
            ldi     1           ; signal end of buffer reached
            shr
fnd_done:   pop     rc          ; restore register            
            return              ; return to caller
            endp


            ;-------------------------------------------------------
            ; Name: find_string
            ;
            ; Find a text string within the buffer
            
            ; Parameters: 
            ;   r8 - current line
            ;   rd - target string
            ;   rb.0 - character position
            ; Uses:
            ;   rf - pointer to buffer with text bytes
            ;   rc.0 - count of bytes, index of found string
            ;   r9.1 - original character position
            ; Returns:
            ;   DF = 1, match found
            ;   DF = 0, no match found
            ;   r8 - line with match
            ;   rb.0 - character position
            ;-------------------------------------------------------       
            proc  find_string
            push  rf              ; save registers
            push  rd
            push  rc
            push  r9
            
            glo   rb              ; get character position
            phi   r9              ; save in r9.1 in case never found

          
            call  find_line       ; find current line in r8
fs_nextln:  lda   ra              ; ra points to size of line to search
            lbz   fs_notfnd       ; if end of buffer, we never found it

            plo   rc              ; set up count
            load  rf, work_buf    ; set pointer to working buffer
fs_copy:    lda   ra              ; get a byte from the current line
            str   rf              ; put in working buffer 
            inc   rf              ; move pointer to next position
            dec   rc              ; count down
            glo   rc              ; check counter
            lbnz  fs_copy         ; keep going until count exhausted

            ldi   0               ; remove CRLF at end
            dec   rf
            str   rf              ; replace LF with null
            dec   rf              
            str   rf              ; replace CR with null
            
            load  rf, work_buf    ; set pointer back to beginning of source
            glo   rb              ; get original character position
            lbz   fs_search       ; if no offset, search the whole string

            str   r2              ; save cursor position in M(X)
            glo   rf              ; get low byte of buffer pointer
            add                   ; add cursor position to low byte
            plo   rf              ; save updated low byte
            ghi   rf              ; get high byte of buffer pointer
            adci  0               ; add carry to high byte
            phi   rf              ; update high byte of the buffer
            
fs_search:  call  strstr          ; check to see if string is in source
            lbdf  fs_found        ; we found it, exit with line value
            inc   r8              ; increment line count to next line
            ldi   0
            plo   rb              ; set cursor position to zero for next line
            lbr   fs_nextln       ; continue searching buffer
            
fs_found:   glo   rc              ; get offset of matching string
            str   r2              ; save offset in M(X)
            glo   rb              ; get current search position in line
            add                   ; add in offset
            plo   rb              ; set as current character for result
            call  setcurln        ; save matching line in r8 as current line
            stc                   ; set DF = 1, to indicate match 
            lbr   fs_exit
            
fs_notfnd:  call  getcurln        ; restore r8 to current line index
            ghi   r9              ; get original character position
            plo   rb              ; restore character position
            clc                   ; clear DF to indicate not found  
            
fs_exit:    pop   r9              ; restore registers
            pop   rc
            pop   rd
            pop   rf
            return 
            endp
                                   
            ;-------------------------------------------------------
            ; Name: load_buffer
            ;
            ; Open a file and read it into the text buffer
            
            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   rc.0 - byte count
            ;   r7.0 - flags register
            ; Returns:
            ;   DF = 1 - new file
            ;   DF = 0 - file loaded into buffer
            ;-------------------------------------------------------                       
            proc  load_buffer
            push  rf            ; save registers used    
            push  rd
            push  rc
            push  r7  

            load  rf, fname
            load  rd, fildes    ; point to file descriptor     
            ldi   0             ; flags
            plo   r7
            call  o_open        ; attempt to open the file
            lbdf  new_kfile     ; jump if file does not exist
            
            load  rf, textbuf   ; point to text buffer
loadlp:     push  rf            ; save buffer address
            inc   rf            ; point to position after length
            call  readln        ; read next line
            lbdf  loadeof       ; jump if eof was found

            glo   rc            ; get count
            lbnz  loadnz        ; jump if bytes were read
            pop   rf            ; recover buffer
            lbr   loadlp        ; loop back and read another line

loadnz:     ldi   13            ; write cr/lf to buffer
            str   rf
            inc   rf
            ldi   10
            str   rf
            inc   rc            ; add 2 characters
            inc   rc
            pop   rf            ; recover buffer address
            glo   rc            ; get count
            str   rf            ; and write to buffer
            inc   rf            ; move buffer to next line position
            str   r2
            glo   rf
            add
            plo   rf
            ghi   rf
            adci   0
            phi   rf
            lbr   loadlp        ; jump to load next line

loadeof:    pop   rf            ; recover buffer address
            glo   rc            ; see if bytes were read
            lbz   loaddn        ; jump if not

            ldi   13            ; write cr/lf to buffer
            str   rf
            inc   rf
            ldi   10
            str   rf
            inc   rc            ; add 2 characters
            inc   rc
            glo   rc            ; get count
            str   r2
            glo   rf
            add
            plo   rf
            ghi   rf
            adci  0
            phi   rf
loaddn:     ldi   0             ; write termination
            str   rf
            call  o_close       ; close the file
            clc                 ; clear the DF flag
new_kfile:  pop   r7            ; restore registers
            pop   rc
            pop   rd
            pop   rf
            return
            endp

            
            ;-------------------------------------------------------
            ; Name: readln
            ;
            ; Read a line from a file into the text buffer
            ;
            ; Parameters
            ;   rf - pointer to text buffer
            ; Uses:
            ;   rc - byte count    
            ; Returns:
            ;   DF = 0, line read 
            ;   DF = 1, end of file encountered
            ;-------------------------------------------------------            
            proc  readln
            ldi   0             ; set byte count
            phi   rc
            plo   rc
readln1:    call  readbyte      ; read a byte
            lbdf  readlneof     ; jump on eof

            plo   re            ; keep a copy
            smi   32            ; look for anything below a space
            lbnf  readln1
            
readln2:    glo   re            ; recover byte
            str   rf            ; store into buffer
            inc   rf            ; point to next position
            inc   rc            ; increment character count
            call  readbyte      ; read next byte
            lbdf  readlneof     ; jump if end of file
            plo   re            ; keep a copy of read byte
            smi   32            ; make sure it is positive
            lbdf  readln2       ; loop back on valid characters
            ldi   0             ; signal valid read
readlncnt:  shr                 ; shift into DF
            return              ; and return to caller
readlneof:  ldi   1             ; signal eof
            lbr   readlncnt
            endp

            ;-------------------------------------------------------
            ; Name: readbyte
            ;
            ; Read a byte from a file into the character buffer
            ;
            ; Parameters
            ;   rf - pointer to text buffer
            ; Uses:
            ;   rc - byte count    
            ; Returns:
            ;   DF = 0, byte read 
            ;   DF = 1, end of file encountered
            ;-------------------------------------------------------
            proc  readbyte
            push  rf
            push  rc
            load  rf, k_char
            ldi   0
            phi   rc
            ldi   1
            plo   rc
            call  o_read
            glo   rc
            lbz   readbno
            ldi   0
readbcnt:   shr
            load  rf, k_char
            ldn   rf
            plo   re
            pop   rc
            pop   rf
            glo   re
            return
readbno:    ldi   1
            lbr   readbcnt
            endp

            ;-------------------------------------------------------
            ; Name: save_buffer
            ;
            ; Save the text buffer to a file.

            ; Parameters: (file name in fname buffer) 
            ; Uses:
            ;   rf - pointer to text bytes
            ;   rd - pointer to file descripter
            ;   rc - byte count
            ;   r7.0 - flags register
            ; Returns: 
            ;   DF = 0, buffer saved successfully
            ;   DF = 1, an error occurred when saving buffer
            ;-------------------------------------------------------                       
            proc  save_buffer    
            push  rf              ; save registers used in save
            push  rd
            push  rc
            push  r7

            load  rf, fname     ; point to filename
            load  rd, fildes    ; point to file descriptor
            ldi   3             ; flags for open, create, truncate
            plo   r7
            call  o_open        ; open the file
            lbdf  save_exit     ; if we can't open file exit with error
            
            load  rf, textbuf   ; point to text buffer
savelp:     ldn   rf            ; get length byte
            lbz   savedn        ; jump if done

            push  rf            ; save buffer position
            lda   rf            ; get length byte
            plo   rc
            ldi   0             ; clear high byte of count
            phi   rc
            call   o_write      ; write the line
            pop   rf            ; recover buffer
            lbdf  save_err      ; if we had a write error, exit
            
            lda   rf            ; get length byte
            str   r2            ; and add to position
            glo   rf
            add
            plo   rf
            ghi   rf
            adci  0
            phi   rf
            lbr   savelp        ; loop back for next line

save_err:   call  o_close       ; attempt to close open file
            stc                 ; set DF=1 for error
            lbr   save_exit     ; exit with error
            
savedn:     call  o_close           ; close the file
            call  clear_file_bits   ; clear the dirty flag and new flag bits
            clc                 ; clear DF flag for successful return
save_exit:  pop   r7            ; restore registers used
            pop   rc
            pop   rd
            pop   rf 
            return 
            endp


            ;-------------------------------------------------------
            ; Name: insert_line
            ;
            ; Insert a line of text into the text buffer.

            ; Parameters: 
            ;   rf - pointer to text string
            ;   ra - pointer to current line
            ;   r8 - current line number
            ; Uses:
            ;   rd - destination pointer to text buffer
            ;   rc.0 - byte count
            ;   r9 - source pointer
            ;
            ; Returns:
            ;   r8 - new current line number
            ;-------------------------------------------------------                       
            proc  insert_line
            push  rd            ; save registers used
            push  rc
            push  r9
            
insertln:   ldi   0             ; setup count
            plo   rc
            phi   rc
            push  rf            ; save buffer position
insertlp1:  inc   rc            ; increment count
            lda   rf            ; get next byte
            lbnz  insertlp1
            glo   rc            ; get count + 1 for size byte
            stxd                ; and save it
            call  find_eob      ; find end of buffer
            glo   rc            ; add in count to get destination
            str   r2
            glo   ra
            plo   r9
            add
            plo   rd
            ghi   ra
            phi   r9            ; r9 points to end of old buffer
            adci  0
            phi   rd            ; rd point to end of new buffer     
            call  getcurln      ; get current line number
            call  find_line     ; find address of line
insertlp2:  ldn   r9            ; read source byte from end
            str   rd            ; place into destination
            glo   ra            ; check for completion
            str   r2
            glo   r9
            sm
            lbnz  inslp2c
            ghi   ra            ; check for completion
            str   r2
            ghi   r9
            sm
            lbnz  inslp2c
            lbr   inslp2d
inslp2c:    dec   r9            ; decrement positions
            dec   rd
            lbr   insertlp2     ; keep going until r9 = ra
inslp2d:    call  getcurln      ; get current line number
            call  find_line     ; find address of line
            irx                 ; recover count
            ldx
            smi    1            ; subtract out length byte from count
            str   ra            ; store into buffer
            inc   ra            ; point ra to next byte in buffer
            plo   rc            ; put into count
            pop   rf            ; recover input buffer
insertlp3:  glo   rc            ; get count
            lbz   insertdn      ; jump if done
            lda   rf            ; get byte from input
            str   ra            ; store into text buffer
            inc   ra
            dec   rc            ; decrement count
            lbr   insertlp3     ; loop back until done
insertdn:   call  getcurln      ; get current line number
            
            call  set_dirty     ; set the dirty bit after buffer change            

            pop   r9            ; restore registers used
            pop   rc
            pop   rd
            return              ; return to caller
            endp
            
            ;-------------------------------------------------------
            ; Name: delete_line
            ;
            ; Delete current line from text buffer.

            ; Parameters:  
            ;   r8 - current line number
            ;   ra - pointer to current line
            ; Uses:
            ;   rd - destination pointer
            ;   rc - byte count
            ; Returns: 
            ;   DF = 0, if deleted
            ;   DF = 1, if not deleted
            ;   r8 - new currrent line
            ;-------------------------------------------------------                       

            proc  delete_line
            push  rd            ; save registers used
            push  rc
kill:       call  find_line     ; check if exists
            lbdf  killquit
            ghi   ra            ; save dest pointer
            phi   rd
            glo   ra
            plo   rd
            inc   r8            ; move to next line
            call  find_line     ; get address for line
killline:   ldn   ra            ; get length to next line
            lbz   killdone
            adi   1
            plo   rc
killloop:   lda   ra            ; get source byte
            str   rd            ; place into destintion
            inc   rd
            dec   rc            ; decrement count
            glo   rc            ; get count
            lbnz  killloop      ; loop until line is done
            lbr   killline      ; and loop for next line
killdone:   str   rd
            call  set_dirty     ; set the dirty bit after buffer change
            clc            
killquit:   call  getcurln      ; set r8 back to current line
            pop   rc            ; restore registers
            pop   rd    
            return
            endp      
            
            ;-------------------------------------------------------
            ; Name: update_line
            ;
            ; If the current line exists, insert a line of new text
            ; into the text buffer as the current line and delete
            ; the old line of text.  If the current line is not in  
            ; the buffer, append text to end of buffer. 
            ;
            ; Parameters: 
            ;   rf - pointer to new text string
            ;   r8 - current line number
            ; Uses:
            ;   ra - pointer to current line
            ;   r8 - current line number
            ;
            ; Returns:
            ;   DF = 0, line is updated
            ;   DF = 1, new line appended to buffer
            ;   r8 - new current line number
            ;-------------------------------------------------------                       
            proc  update_line
            call  find_line     ; check current line
            call  insert_line   ; insert new text
            
            inc   r8            ; move to the previous line number
            call  setcurln      ; and save it for delete
            
            call  delete_line   ; delete the previous line of text
            dec   r8            ; move back to new line
            call  setcurln      ; save it for refresh
            clc                 ; clear DF to indicate line updated
            return
            endp
            
            ; ***************************************
            ; ***      File and Data Buffers      ***
            ; ***************************************
            
            proc  fname
              ds      80        ; file name
            endp
              
            proc  fildes
              db      0,0,0,0   ; file descriptor
              dw      k_dta
              db      0,0
              db      0
              db      0,0,0,0
              dw      0,0
              db      0,0,0,0
            endp  
  
            proc  curline
              dw      0         ; current line variable
            endp

            proc  k_char
              db      0         ; character read from file
            endp  

            proc  k_dta
             ds      512        ; data transfer area  
            endp 
                     
            ; text buffer format
            ; byte size of line (0 if end of buffer)
.link .align para               
            proc  textbuf
              db      0
            endp
