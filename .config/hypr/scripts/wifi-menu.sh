#!/usr/bin/env bash
dbus-send --session --type=method_call --dest=org.josue.wifi /org/josue/wifi org.josue.wifi.toggle

