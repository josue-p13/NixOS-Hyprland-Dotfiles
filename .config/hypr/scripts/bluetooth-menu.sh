#!/usr/bin/env bash
dbus-send --session --type=method_call --dest=org.josue.bluetooth /org/josue/bluetooth org.josue.bluetooth.toggle
