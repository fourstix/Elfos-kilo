[Your_Path]\Asm02\asm02 -L -D1802MINIPLUS kilo.asm
[Your_Path]\Asm02\asm02 -L -D1802MINIPLUS kilo_util.asm
[Your_Path]\Asm02\asm02 -L -D1802MINIPLUS kilo_keys.asm
[Your_Path]\Asm02\asm02 -L -D1802MINIPLUS kilo_file.asm

[Your_Path]\Link02\link02 -e -s kilo.prg kilo_util.prg kilo_keys.prg kilo_file.prg  
