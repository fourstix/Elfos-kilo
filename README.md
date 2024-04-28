# Elfos-kilo
A full screen editor for the Elf/OS written in 1802 Assembly language and based loosely on the [Kilo editor](https://github.com/antirez/kilo) by Salvatore Sanfilippo aka antirez and the [Elfos-Edit editor](https://github.com/rileym65/Elf-Elfos-edit) by Mike Riley.

Platform
--------
The Elf/OS kilo editor was written for an 1802 based Microcomputer running the Elf/OS operating system, such as the [Pico/Elf](http://www.elf-emulation.com/picoelf.html) by Mike Riley or the [1802-Mini](https://github.com/dmadole/1802-Mini) by David Madole. A lot of information and software for the Pico/Elf and the 1802-Mini can be found on the [Elf-Emulation](http://www.elf-emulation.com/) website and in the [COSMAC ELF Group](https://groups.io/g/cosmacelf) at groups.io.

The Elf/OS kilo editor were assembled and linked with updated versions of the Asm-02 assembler and Link-02 linker by Mike Riley. The updated versions required to assemble and link this code are available at [arhefner/Asm-02](https://github.com/arhefner/Asm-02) and [arhefner/Link-02](https://github.com/arhefner/Link-02).


Elf/OS Kilo Commands
--------------------
<table>
<tr><th>Keys</th><th>Command</th></tr>
<tr><td>Ctrl+B, Home</td><td>Move to the Beginning of line</td></tr>
<tr><td>Ctrl+C</td><td>Copy line to clip board</td></tr>
<tr><td>Ctrl+D, Down</td><td>Move cursor Down</td></tr>
<tr><td>Ctrl+E, End</td><td>Move to End of line</td></tr>
<tr><td>Ctrl+F</td><td>Find text</td></tr>
<tr><td>Ctrl+G</td><td>Go to line number</td></tr
<tr><td>Ctrl+H, Backspace</td><td>Move back and delete character</td></tr>
<tr><td>Ctrl+I, Tab</td><td>Move forward to next tab stop</td></tr>
<tr><td>Ctrl+J</td><td>Join lines</td></tr>
<tr><td>Ctrl+K, Delete</td><td>Delete (Kill) character</td></tr>
<tr><td>Ctrl+L, Left</td><td>Move cursor Left</td></tr>
<tr><td rowspan="2">Ctrl+M, Enter</td><td>Insert Mode: insert new line or split at cursor</td></tr>
<tr><td>Overwrite Mode: Move down to the next line.</td></tr>
<tr><td>Ctrl+N, PgDn</td><td>Next screen</td></tr>
<tr><td>Ctrl+O, Insert</td><td>Toggle Overwrite/insert Mode screen</td></tr>
<tr><td>Ctrl+P, PgUp</td><td>Previous screen</td></tr>
<tr><td>Ctrl+Q</td><td>Quit, confirm if file changed</td></tr>
<tr><td>Ctrl+R, Right</td><td>Move cursor Right</td></tr>
<tr><td>Ctrl+S</td><td>Save file</td></tr>
<tr><td>Ctrl+T</td><td>Move to Top of file</td></tr>
<tr><td>Ctrl+U, Up</td><td>Move cursor Up</td></tr>
<tr><td>Ctrl+V</td><td>Paste line from clip board</td></tr>
<tr><td>Ctrl+W</td><td>show Where cursor is located in file</td></tr>
<tr><td>Ctrl+X</td><td>Cut line into clip board</td></tr>
<tr><td>Ctrl+Y</td><td>Save As new file</td></tr>
<tr><td>Ctrl+Z</td><td>Move to bottom of file</td></tr>
<tr><td>Ctrl+], Shift+Tab</td><td>Move back to previous tab stop</td></tr>
<tr><td>Ctrl+\</td><td>Split line at cursor</td></tr>
<tr><td>Ctrl+?</td><td>Show help information</td></tr>
</table>


Elf/OS Kilo Modes
-----------------
* **Insert Mode**
  * Characters are inserted into the text
  * Enter inserts a new line or splits a line at the cursor
* **Overwrite Mode** 
  * Characters overwrite existing characters in the text
  * Enter moved down to the beginning of the next line 

Repository Contents
-------------------
* **/src/**  -- Source files for the Elf/OS kilo editor.
  * kilo.asm - Main assembly source file.
  * kilo_file.asm - Assembly source file for file routines.
  * kilo_util.asm - Assembly source file for utility routines.
  * kilo_keys.asm - Assembly source file for key handler routines.
  * build.bat - Windows batch file to assemble and create the Elf/OS kilo editor.
  * clean.bat - Windows batch file to delete the executable and the associated build files.   
* **/src/include/**  -- Include files for the graphics display programs and their libraries.  
  * kilo_def.inc - Definitions for Elf/OS kilo source files.
  * ops.inc - Opcode definitions for Asm/02.
  * bios.inc - Bios definitions from Elf/OS
  * kernel.inc - Kernel definitions from Elf/OS
* **/bin/**  -- Binary files for Elf/OS kilo editor.
  * kilo.elfos - Elf/OS binary file for the Elf/OS kilo editor


License Information
-------------------
This code is public domain under the MIT License, but please buy me a beverage
if you use this and we meet someday (Beerware).

References to any products, programs or services do not imply
that they will be available in all countries in which their respective owner operates.

Any company, product, or services names may be trademarks or services marks of others.

All libraries used in this code are copyright their respective authors.

This code is based on a Elf/OS kernel written by Mike Riley and created with the Asm/02 assembler and Link/02 linker also written by Mike Riley.

Elf/OS 
Copyright (c) 2004-2024 by Mike Riley

Kilo Editor 
Copyright (c) 2016-2024 by Salvatore Sanfilippo

Elf-Elfos-Edit 
Copyright (c) 2004-2024 by Mike Riley

Asm/02 1802 Assembler
Copyright (c) 2004-2024 by Mike Riley

Link/02 1802 Linker
Copyright (c) 2004-2024 by Mike Riley

Many thanks to the original authors for making their designs and code available as open source.
 
This code, firmware, and software is released under the [MIT License](http://opensource.org/licenses/MIT).

The MIT License (MIT)

Copyright (c) 2024 by Gaston Williams

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.**
