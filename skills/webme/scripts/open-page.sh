#!/usr/bin/env bash
# Open a webme page in a NEW browser window, so it appears on the workspace /
# virtual desktop you're on. (A new tab would join the browser's existing
# window, wherever that window is.)
#
# Usage: open-page.sh <page.html>
# Browser: ~/webme/.browser — "default" or a command/path for a specific browser.
# Works on Linux, macOS and Windows (Git Bash). Chromium-family browsers
# (Chrome, Edge, Brave, Vivaldi, Opera) and Firefox all accept --new-window.
set -u
page=$1
browser=$(head -1 "$HOME/webme/.browser" 2>/dev/null); browser=${browser:-default}

case "$(uname -s)" in
  Darwin)
    # macOS opens on the current Space unless the app is pinned to another one.
    if [[ $browser == default ]]; then open "$page"; else open -a "$browser" "$page"; fi
    ;;

  MINGW*|MSYS*|CYGWIN*)
    win=$(cygpath -w "$page" 2>/dev/null || echo "$page")
    if [[ $browser == default ]]; then
      # Look up the default browser's executable so we can ask for a new window.
      progid=$(reg.exe query 'HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' //v ProgId 2>/dev/null | awk '/ProgId/{print $NF}' | tr -d '\r')
      exe=$(reg.exe query "HKCR\\$progid\\shell\\open\\command" //ve 2>/dev/null | grep -o '"[^"]*\.exe"' | head -1 | tr -d '"')
      if [[ -n $exe ]]; then "$exe" --new-window "$win" >/dev/null 2>&1 &
      else cmd.exe //c start "" "$win"; fi
    else
      "$browser" --new-window "$win" >/dev/null 2>&1 &
    fi
    ;;

  *)  # Linux / BSD
    cmd=$browser
    if [[ $browser == default ]]; then
      desktop=$(xdg-settings get default-web-browser 2>/dev/null)
      for d in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" /usr/local/share/applications /usr/share/applications; do
        [[ -n $desktop && -f $d/$desktop ]] && { cmd=$(grep -m1 '^Exec=' "$d/$desktop" | sed 's/^Exec=//; s/ %[a-zA-Z]//g'); break; }
      done
      [[ $cmd == default ]] && { setsid xdg-open "file://$page" >/dev/null 2>&1 & exit 0; }
    fi
    setsid $cmd --new-window "file://$page" >/dev/null 2>&1 &
    ;;
esac
