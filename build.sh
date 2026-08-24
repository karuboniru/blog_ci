#!/bin/bash

set -euo pipefail

curl -s -L https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz | tar -Jxvf - -C ./
npm ci
export PATH="$(pwd)/typst-x86_64-unknown-linux-musl:$PATH"
python build.py build -f
rm -rf public
cp -a _site public
npx gulp build
