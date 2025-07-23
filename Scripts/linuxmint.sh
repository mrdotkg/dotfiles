#!/bin/bash

# Generate SSH key
ssh-keygen -t ed25519 -C "grv.rkg@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
xdg-open "https://github.com/settings/ssh/new"