#!/usr/bin/env bash
# Stream DriveCaffeine's keep-alive log. Wrapped in a script so the predicate's
# nested quotes don't trip the monitor's eval.
exec log stream --predicate 'subsystem == "com.example.drivecaffeine"' --info --style compact 2>&1
