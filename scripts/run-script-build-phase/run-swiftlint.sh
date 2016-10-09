#!/bin/bash
if which swiftlint >/dev/null; then
    swiftlint
else
    echo "warning: SwiftLint not installed: did you run scripts/after-clone?"
fi
