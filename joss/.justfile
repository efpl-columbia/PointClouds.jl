# This file contains recipes for the `just` command runner.
# See https://github.com/casey/just for more information.

build: prepare
  cd inara && make pdf ARTICLE=../paper.md TARGET_FOLDER=../build

preview: prepare
  cd inara && make html ARTICLE=../paper.md TARGET_FOLDER=../build

prepare:
  test -d inara || git clone --depth 1 --branch v1.0.0 https://github.com/openjournals/inara
