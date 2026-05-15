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
            # Match lines like "64. Name" or "*   67. Name"
            import re
            match = re.search(r'(\d+)\.\s*(?:\*\s*)?(.+?)\s*\[', line)
            if match:
                id_part = match.group(1)
                name_part = match.group(2).strip()
                devices.append(f'{id_part}: {name_part}')

    return devices

section = 'Sinks'
if len(sys.argv) > 1 and sys.argv[1] == 'sources':
    section = 'Sources'

devices = get_devices(section)
if not devices:
    print('No devices found')
else:
    for d in devices:
        print(d)
