#!/usr/bin/env bash
dbus-send --session --type=method_call --dest=org.josue.audio /org/josue/audio org.josue.audio.toggle
