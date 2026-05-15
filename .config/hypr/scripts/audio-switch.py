#!/usr/bin/env python3
import subprocess
import sys
import os

def get_devices(section='Sinks'):
    result = subprocess.run(['wpctl', 'status'], capture_output=True, text=True)
    output = result.stdout

    devices = []
    current_section = None
    found_section = False

    for line in output.split('\n'):
        if f'├─ {section}:' in line:
            current_section = section
            found_section = True
            continue
        if found_section and ('├─ ' in line or '└─ ' in line):
            if '├─ Sources:' in line or '├─ Filters:' in line:
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

# Write type choice to file
with open('/tmp/wofi_type.txt', 'w') as f:
    f.write('Salida\nEntrada\n')

# First wofi - choose type
result = subprocess.run(['wofi', '-f', '--dmenu', '-p', 'Audio', '-i'],
    stdin=open('/tmp/wofi_type.txt', 'r'), stdout=subprocess.PIPE, stderr=subprocess.PIPE)

choice = result.stdout.decode().strip()

if not choice:
    sys.exit(0)

if 'Salida' in choice:
    devices = sinks
    prompt = 'Salida'
else:
    devices = sources
    prompt = 'Entrada'

# Write devices to file
with open('/tmp/wofi_devices.txt', 'w') as f:
    f.write('\n'.join(devices))

# Second wofi - choose device
result = subprocess.run(['wofi', '-f', '--dmenu', '-p', prompt, '-i'],
    stdin=open('/tmp/wofi_devices.txt', 'r'), stdout=subprocess.PIPE, stderr=subprocess.PIPE)

selected = result.stdout.decode().strip()

# Cleanup
for f in ['/tmp/wofi_type.txt', '/tmp/wofi_devices.txt']:
    if os.path.exists(f):
        os.unlink(f)

if selected and ':' in selected:
    id_val = selected.split(':')[0].strip()
    subprocess.run(['wpctl', 'set-default', id_val])
