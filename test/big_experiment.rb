require 'g5k_api'
require 'benchmark'

g5k_init(
       :site => ["grenoble","bordeaux","sophia","lyon","lille","rennes"],
       :resources => ["nodes=40","nodes=80","nodes=80","nodes=50","nodes=60","nodes=40"],
       :walltime => 500,
       :types => ["allow_classic_ssh"],
       :submission_timeout => 200,
       :name => "Big_experiment"
)

 
g5k_run                     # run the reservation
 
task_mon=Task::new("hostname",$all,"Monitoring")
i


griffon_hosts=t$all["griffon"]
res=0
 time=Benchmark.realtime do
        id, res = task_mon.execute
 end
 puts "Time elapsed in the task : #{time}"
 puts "getting response from : #{res.length} nodes"



#require 'expo_g5k'
#oargridsub :res => "grenoble:rdef=\"/nodes=60\",bordeaux:rdef=\"/nodes=80\",sophia:rdef=\"/nodes=80\",lyon:rdef=\"/nodes=50\"", :walltime=> "0:10:00"
