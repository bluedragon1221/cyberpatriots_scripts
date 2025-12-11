# CyberPatriots Scripts
The goal for this repo is to get 100 points on a linux CyberPatriots image without any user interaction.

> [!NOTE]
> THESE SCRIPTS EXIST FOR PURELY EDUCATIONAL PURPOSES.
> Running automated scripts on real CyberPatriots competition images that you did not personally write violates CP rules.
> Do not run this on any competition image unless you are me.
> Seriously, don’t get me banned ;)

## Features
- Downloads the `README` file to automatically determine desired changes to system users
- Doesn't destructively modify the system, only prints the commands to run
- Each check is its own function, making it easily extendable
- Programmed in Lua, not bash

## Running
Instructions for running (on a personal computer, of course):
```sh
# Install dependencies (on debian system):
sudo apt install -y git lua5.4

# Clone the script
git clone https://github.com/bluedragon1221/cyberpatriots_scripts
cd cyberpatriots_scripts

# Run it (this will print a list of commands to run)
lua linscript.lua

sudo su
# (paste list of commands)
```

## Architecture Overview
All scripts are written in [Lua](https://www.lua.org).
Each script is composed of many checks, which are simply public functions with the name `check_*`.
Checks NEVER permanently change the system, unless caching things to enable faster re-runs (ex. Downloading the README file).

Important files:
- The `lib.lua` file defines helper functions for doing repetitive tasks.
- The `linscript.lua` script imports all other scripts and runs all checks inside them.
