require 'g5k_api'
#require 'expo_g5k'
require 'benchmark'

g5k_init(
       :site => ["grenoble","luxembourg","sophia","lyon","nancy","reims","toulouse","lille"],
       :resources => ["nodes=1","nodes=3","nodes=80","nodes=63","nodes=150","nodes=20","nodes=70","nodes=30"],
       :walltime => 1800,
       :types => ["allow_classic_ssh"],
       :submission_timeout => 600,
       :name => "Big_experiment"
)

 
g5k_run                     # run the reservation

sizes=[10,50,100,200,300]

puts "nb_nodes	time"
sizes.each{ |n|
 	
	nodes=$all.uniq[0..(n-1)]
	task_mon=Task::new("hostname",nodes,"Monitoring")

	res=0
	(0..9).each{ 
 		time=Benchmark.realtime do
        		id, res = task_mon.execute
 		end
 		puts "#{res.length}	#{time}"
	}
}

