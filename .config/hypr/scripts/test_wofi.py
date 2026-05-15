#!/usr/bin/env python3
import subprocess
import sys

def get_devices(section='Sinks'):
    result = subprocess.run(['wpctl', 'status'], capture_output=True, text=True)
    output = result.stdout.decode() if isinstance(result.stdout, bytes) else result.stdout

    devices = []
    current_section = None
    found_section = False

    for line in output.split('\n'):
        if f'├─ {section}:' in line:
            current_section = section
            found_section = True
            continue
        if found_section and ('├─ ' in line or '└─ ' in line):
            if f'├─ {section}:' not in line and '├─ Sources:' not in line and '├─ Filters:' not in line:
                break
        if current_section == section and found_section:
            import re
            match = re.search(r'(\d+)\.\s*(?:\*\s*)?(.+?)\s*\[', line)
            if match:
                id_part = match.group(1)
                name_part = match.group(2).strip()
                devices.append(f'{id_part}: {name_part}')

    return devices

sinks = get_devices('Sinks')
sources = get_devices('Sources')

print("Sinks:", sinks)
print("Sources:", sources)

# Test wofi
proc = subprocess.run(['wofi', '-f', '-d', '-p', 'Test'],
    input='item1\nitem2\nitem3', capture_output=True, text=True)

print("wofi stdout:", repr(proc.stdout))
print("wofi stderr:", repr(proc.stderr))
print("wofi return:", proc.returncode)
