#!/usr/bin/env bash
dbus-send --session --type=method_call --dest=org.josue.monitor /org/josue/monitor org.josue.monitor.toggle

