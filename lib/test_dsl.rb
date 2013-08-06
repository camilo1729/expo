require './DSL'

set :user, "root"
set :hosts, ["192.168.56.101","192.168.56.102"]

task :test_0 do
  run "uname -a"
end

task :test_1 do
  run "sleep 10"
end

task :test_2 do
  run "sleep 1"
end

task :test_3 do
  run "sleep 2"
end

result=nil
task :test_4 do
  result=run "date"
end

task :cpu_info do 
  run "cat /proc/cpuinfo"
end

### taktuk Tasks 

task :hostname do
  run_remote("hostname") 
end

task :sleep do
  run_remote("sleep 100")
end





puts "Output of task 4"
puts "Time: #{result[1]}"
puts "Output:"
puts result[0]

