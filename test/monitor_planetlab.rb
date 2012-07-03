require 'expo_planetlab'
require 'benchmark'
## getting resources form planetlab Slice
get_resources
$ssh_user="lig_expe"
$ssh_timeout="30"
$all.properties={:gateway=>"planetlab-2.imag.fr"}
task_mon=Task::new("hostname",$all,"Monitoring")
File.open("Planetlab_avail.txt",'w+'){|f|
  res=nil
  f.puts "Date \t Time \t Num_Res"
  240.times{
    data_me=Time::now.to_i
    time=Benchmark.realtime do
	id, res = task_mon.execute
    end
    f.puts "#{data_me} \t #{time} \t #{res.length}"
    f.flush
    sleep(60)
    }
}

