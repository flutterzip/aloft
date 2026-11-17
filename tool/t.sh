#!/bin/bash
# Runs tests and prints only what failed and why.
cd "$(dirname "$0")/.."
flutter test "$@" 2>&1 | tr '\r' '\n' | grep -E "overflowed|relevant error-causing|^  (Column|Row|Stack|Flex).*file:|\[E\]|Expected:|Actual:|Which:|The following|tests passed|Some tests failed|^.*test\.dart [0-9]+:[0-9]+ |pumpAndSettle timed out|Warning: A call to tap" | sed "s#file://$PWD/##" | cut -c1-230 | awk '!seen[$0]++' | head -${LINES_MAX:-60}
