; -------------------------------------------------------------------
; Routines to support a screen editor based on the Kilo editor, 
; a small text editor in less than 1K lines of code 
; written by Salvatore Sanfilippo aka antirez 
; available at https://github.com/antirez/kilo
; and described step-by-step at the website 
; https://viewsourcecode.org/snaptoken/kilo/index.html
; -------------------------------------------------------------------
; Also based on the Elf/OS edit program written by Michael H Riley
; available https://github.com/rileym65/Elf-Elfos-edit
; -------------------------------------------------------------------
; Copyright 2024 by Gaston Williams
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


;-------------------------------------------------------------------------------
; Uncomment to enable Debug code 
;-------------------------------------------------------------------------------
; #define  KILO_DEBUG  1

;-------------------------------------------------------------------------------
; Uncomment to enable flow control (Xon/Xoff) 
;-------------------------------------------------------------------------------
#define  KILO_FLOW   1

;-------------------------------------------------------------------------------
; Comment out to remove Help information (about 1K in size) 
;-------------------------------------------------------------------------------
#define  KILO_HELP  1


;-------------------------------------------------------------------------------
; Default Screen Size Constants
;-------------------------------------------------------------------------------
#define DEF_LINES 24
#define DEF_COLS  80

;-------------------------------------------------------------------------------
; Maximum Line Size and Column Position 
;-------------------------------------------------------------------------------
#define MAX_LINE  124 
#define MAX_COL   123 
#define MAX_FNAME  19
#define MAX_INTSTR  5
#define MAX_TARGET 40

;-------------------------------------------------------------------------------
; Editor State bits
;-------------------------------------------------------------------------------
#define DIRTY_BIT     $80
#define DIRTY_MASK    $7F
#define REFRESH_BIT   $40
#define REFRESH_MASK  $BF 
#define MODE_BIT      $20
#define MODE_MASK     $DF
#define NEWFILE_BIT   $10
#define NEWFILE_MASK  $EF
#define STATUS_BIT    $08
#define STATUS_MASK   $F7
#define ERROR_BIT     $01
#define ERROR_MASK    $FE

;---- Mask for clearing dirty and new file bits at same time (file saved)
#define SAVED_MASK    $6F
;---- Mask for clearing refresh and status bits at same time (screen updated)
#define SCREEN_MASK   $B7


#ifdef  KILO_FLOW

;-------------------------------------------------------------------------------
; Software Flow Control Characters
;-------------------------------------------------------------------------------
#define XON   17
#define XOFF  19

#endif

;-------------------------------------------------------------------------------
; Utility routines used by kilo editor
;-------------------------------------------------------------------------------
            extrn   set_window_size
            extrn   window_height
            extrn   window_width 
            extrn   window_size
            extrn   clear_screen
            extrn   set_cursor
            extrn   get_cursor
            extrn   move_cursor
            extrn   home_cursor
            extrn   scroll_up
            extrn   scroll_down
            extrn   scroll_left
            extrn   scroll_right
            extrn   refresh_screen
            extrn   refresh_line
            extrn   set_row_offset
            extrn   get_row_offset
            extrn   set_col_offset
            extrn   get_col_offset
            extrn   set_num_lines
            extrn   get_num_lines
            extrn   inc_num_lines
            extrn   dec_num_lines
            extrn   prt_status
            extrn   put_line_buffer
            extrn   pad_line
            extrn   e_state
            extrn   line_buf
            extrn   work_buf
            extrn   num_buf
            extrn   set_status
            extrn   set_input
            extrn   begin_kilo
            extrn   end_kilo
            extrn   strstr
            extrn   prt_status_dbg
            extrn   prt_find_dbg
            extrn   kilo_status
            extrn   set_dirty
            extrn   clr_file_bits
            extrn   is_dirty
            extrn   is_fnchar
            extrn   split_line
            extrn   join_lines
            extrn   is_eof
            extrn   found_screen
            extrn   clip_brd
            extrn   set_status_cmd

;-------------------------------------------------------------------------------
; Key handler routines used by kilo editor
;-------------------------------------------------------------------------------

            extrn   do_kilo
            extrn   do_home
            extrn   do_mode
            extrn   do_del 
            extrn   do_end
            extrn   do_pgup
            extrn   do_pgdn
            extrn   do_up
            extrn   do_down
            extrn   do_left
            extrn   do_rght
            extrn   do_backspace
            extrn   do_tab
            extrn   do_bktab
            extrn   do_enter
            extrn   do_return
            extrn   do_newline
            extrn   do_save
            extrn   do_kill
            extrn   do_split
            extrn   do_join
            extrn   do_typeover
            extrn   do_typein
            extrn   do_insline
            extrn   do_top
            extrn   do_bottom
            extrn   do_quit
            extrn   do_confirm
            extrn   do_where
            extrn   do_input
            extrn   do_goto
            extrn   do_change
            extrn   do_find
            extrn   do_copy
            extrn   do_paste
            extrn   do_help  

;-------------------------------------------------------------------------------
; File routines used by kilo editor
;-------------------------------------------------------------------------------            
                        
            extrn   find_eob
            extrn   find_line
            extrn   getcurln
            extrn   setcurln
            extrn   fname 
            extrn   load_buffer
            extrn   save_buffer
            extrn   insert_line
            extrn   delete_line
            extrn   update_line
            extrn   find_string
            extrn   set_page
            extrn   check_page
