require './DSL'


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

task :test_4 do
  run "date"
end

task :cpu_info do 
  run "cat /proc/cpuinfo"
end
