##!/usr/bin/ruby 


#require '../lib/command'
require '../lib/cmdctrl'
#require '../lib/command_with_open3'
#puts "Testing command execution"
#cmd=Command.new("cat /proc/cpuinfo")
cmd = CtrlCmd.new("sleep 4 & ls")
cmd.run
#system("ls")
puts "command output"
puts cmd.stdout
puts "command Run time "
puts cmd.run_time
