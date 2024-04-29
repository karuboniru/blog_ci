#!/bin/bash

curl -s -L https://github.com/jgm/pandoc/releases/download/3.1.13/pandoc-3.1.13-linux-amd64.tar.gz | tar xvzf - -C ./
# npm i -g hexo-cli gulp gulp-uglify
# npm i
export PATH="$(pwd)/pandoc-2.9.2.1/bin:$PATH"
hexo generate && gulp build
