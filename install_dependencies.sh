#!/bin/sh

echo "Installing gems dependencies"
gem install pry restfully ap crack net-ssh net-scp net-sftp
echo "Installing TakTuk"
aptitude install taktuk
