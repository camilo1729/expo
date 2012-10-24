require 'g5k_api'

	g5k_init(:site => ["lille", "grenoble"],:resources => ["nodes=2"],:walltime => 100) 

  g5k_run                     # run the reservation

  task1=Task::new("hostname",$all,"Test 1")   # Definition of the task to execute
  id, res = task1.execute                     # Execution of the task
  res.each { |r| puts r.duration }            # Printing out the duration of each execution.
  puts "mean : " + res.mean_duration.to_s     # Printing out the mean duration of the tasks.


