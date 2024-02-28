#!/usr/bin/env bash

#FUNCTIONS

# params: package name, verify package name
insure_package() {
  local package="$1"
  if [ -z $(apk info | egrep "^$package$") ]
    then
    echo installing missing package: $package
    apk add $package
  fi
}