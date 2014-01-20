#!/bin/sh

echo "Installing gems dependencies"
gem install pry restfully ap crack net-ssh net-scp net-stfp
echo "Installing TakTuk"
aptitude install taktuk
