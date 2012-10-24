require 'g5k_api'
#require 'expo_g5k'
require 'benchmark'

g5k_init(
       :site => ["nancy"],
       :resources => ["nodes=50"],
       :walltime => 800,
       :types => ["allow_classic_ssh"],
       :submission_timeout => 600,
       :name => "Big_experiment"
)


g5k_run                     # run the reservation

sizes=[10,20,30,40,50]

File.open('results_little_test.txt','w') do | f_result|

        f_result.puts "nb_nodes time"
        sizes.each{ |n|

                nodes=$all.uniq[0..(n-1)]
                task_mon=Task::new("hostname",nodes,"Monitoring")
   		res=0
                (0..9).each{
                        time=Benchmark.realtime do
                                id, res = task_mon.execute
                                end
                f_result.puts "#{res.length}    #{time}"
        }
        }

end

