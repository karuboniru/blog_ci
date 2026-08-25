#!/bin/bash

set -euo pipefail

git_history_state="$(git rev-parse --is-shallow-repository)"
echo "Sitemap Git history: shallow=${git_history_state}"
if [[ "${git_history_state}" == "true" ]]; then
    echo "Fetching complete Git history for sitemap lastmod dates..."
    git fetch --unshallow --no-tags origin
    echo "Sitemap Git history: shallow=$(git rev-parse --is-shallow-repository)"
fi

curl -s -L https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz | tar -Jxvf - -C ./
npm ci
export PATH="$(pwd)/typst-x86_64-unknown-linux-musl:$PATH"
python build.py build -f
rm -rf public
cp -a _site public
npx gulp build
