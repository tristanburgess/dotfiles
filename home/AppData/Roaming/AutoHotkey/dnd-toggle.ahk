#Requires AutoHotkey v2.0
;
; Global Win+Shift+D -> ~/bin/toggle-dnd.sh in Git Bash.
; toggle-dnd.sh handles cross-OS sync (flips Windows ToastEnabled,
; mirrors the ~/.claude-dnd flag into WSL via wsl.exe).
;
; Bound to match the Linux Cinnamon/KDE shortcut so DND lives at the
; same key on every host.

#+d::{
    localAppData := EnvGet("LOCALAPPDATA")
    bashCandidates := [
        "C:\Program Files\Git\bin\bash.exe",
        localAppData "\Programs\Git\bin\bash.exe"
    ]
    bashExe := ""
    for path in bashCandidates {
        if FileExist(path) {
            bashExe := path
            break
        }
    }
    if bashExe = "" {
        MsgBox "Git Bash not found; cannot toggle DND.", "AutoHotkey", "Iconx"
        return
    }
    Run(Format('"{1}" -lc "$HOME/bin/toggle-dnd.sh"', bashExe), , "Hide")
}
