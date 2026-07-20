#!/usr/bin/env bash

codesign_details_has_hardened_runtime() {
  if [[ $# -ne 1 || ! -f "$1" ]]; then
    return 2
  fi

  grep -Eq '(^|[[:space:]])flags=[^[:space:]]*[(,]runtime[),]' "$1"
}
