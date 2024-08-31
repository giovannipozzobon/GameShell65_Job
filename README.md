# FirstShot
 Mega65 Shmup

# Sublime
 Using these settings

# Launching
    "kickass_run_command_x64": "\"${kickass_run_path}\" -besure -prg bin/main.prg -uartmon :4510",
    "kickass_run_command_x64": "\"${kickass_run_path}\" -besure -autoload -8 fshot.d81 -uartmon :4510",

    & "C:\_MEGA65\tools\M65Connect\M65Connect Resources\m65.exe" -l COM7 -F -r .\bin\startup.prg
    .\build\mega65_ftp.exe -l COM7 -c "put fshot.d81" -c "quit"
    
