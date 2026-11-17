#!/bin/bash
# Runs Aloft on the iPhone 17 Pro Max simulator, stdin on a FIFO:
#   echo r > /tmp/aloft/fifo   hot reload     (R restart, q quit)
# The FIFO lives outside the project: a pipe inside it hangs `flutter build`.
# Extra arguments go to `flutter run` (for example --dart-define=startTab=shop).
cd "$(dirname "$0")/.."
mkdir -p /tmp/aloft
rm -f /tmp/aloft/fifo
mkfifo /tmp/aloft/fifo
sleep 100000 > /tmp/aloft/fifo &
HOLD=$!
trap 'kill $HOLD 2>/dev/null' EXIT
flutter run -d "${ALOFT_DEVICE:-44CDDB86-D61F-47C8-8C65-7C87828A38C5}" "$@" < /tmp/aloft/fifo > /tmp/aloft/run.log 2>&1
