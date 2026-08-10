#!/usr/bin/env python3
import subprocess
import sys
import json

# Block characters mapping
BARS = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

# Run CAVA subprocess
cava_cmd = ["cava", "-p", "/home/josue/.config/cava/config_waybar"]
proc = subprocess.Popen(cava_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

silence_counter = 0
SILENCE_THRESHOLD = 30  # 30 frames of silence (1 second at 30 fps)

try:
    for line in proc.stdout:
        line = line.replace("\x00", "").strip()
        if not line:
            continue
        
        # Parse values directly as characters
        if all(c == "0" for c in line):
            silence_counter += 1
        else:
            silence_counter = 0
            
        if silence_counter >= SILENCE_THRESHOLD:
            output = {
                "text": "",
                "class": "silent"
            }
        else:
            bar_chars = []
            for c in line:
                if c.isdigit():
                    idx = int(c)
                    if 0 <= idx < len(BARS):
                        bar_chars.append(BARS[idx])
                    else:
                        bar_chars.append(" ")
                else:
                    bar_chars.append(" ")
            
            output = {
                "text": "".join(bar_chars),
                "class": "playing"
            }
            
        sys.stdout.write(json.dumps(output) + "\n")
        sys.stdout.flush()

except KeyboardInterrupt:
    pass
finally:
    proc.terminate()
