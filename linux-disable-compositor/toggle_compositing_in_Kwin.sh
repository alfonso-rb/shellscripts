#!/bin/bash

# Disable kwin compositor toggle script
#
# Copyright (c) 2020 Alfonso Brown <alfonsob at acbss.com> and others.
# This software is licensed under the GPL v2 or later.

echo -n "Changing compositing state..."
if [ `qdbus org.kde.KWin /Compositor active` = true ]; then
    qdbus org.kde.KWin /Compositor suspend
    echo -n "Compositor disabled.  "
else
    qdbus org.kde.KWin /Compositor resume
    echo -n "Compositor enabled.  "
fi

echo "All done."

# echo -n "All done. Press ENTER to close window: "
# read ENTRY
