#!/usr/bin/env bash
dbus-send --session --type=method_call --dest=org.josue.mixer /org/josue/mixer org.josue.mixer.toggle
