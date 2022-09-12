#!/usr/bin/env bash

branch () {
  git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/  [\\1]/"
}

PS1="\W\[\e[0;35m\]\$(branch)\[\e[m\]  "
