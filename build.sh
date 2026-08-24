#!/bin/bash

curl -s -L https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz | tar -Jxvf - -C ./
# npm i
export PATH="$(pwd)/typst-x86_64-unknown-linux-musl:$PATH"
python build.py build -f
cp -a _site public
