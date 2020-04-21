# DISABLE Compositor Scripts

> Script to disable compositor in Manjaro/Arch from the shell. Also an additional file to stop/start compositor on suspend/resume. There is a known issue with kscreenlocker_greet taking 100% of 1 CPU on resume with compositor enabled.

## Installation

Linux:

```sh
cp toggle_compositing_in_Kwin.sh /usr/local/bin
cp disable_compositor /usr/lib/systemd/system-sleep/
chmod +x /usr/lib/systemd/system-sleep/disable_compositor
```

## Usage example

To run the command manually (to verify it works):

```sh
$>toggle_compositing_in_Kwin.sh
```

## Release History

* 0.0.1
    * Initial files.

## Meta

Alfonso Brown
- @AlfieRB (https://twitter.com/AlfieRB)
- alfonsobATacbssDOTcom
- https://github.com/alfonso-rb
