require 'yaml'
require 'expo_g5k'
require 'date'

oargridconnect ARGV[0]

binaries = Array::new
task = Task::new (" ls pastel/pastel−stable/bin", $all.first)
 number,result = task.execute
 binaries = result.first["stdout"].split
 binaries.sort!

 sizes = []
 for i in 10 .. 100 do
	sizes.push((2**(27.0 * (i.fdiv 100.0))).to_int)
 end
 sizes.uniq!

 file = File::new("Experiment−#{$client.experiment_number .\
experiment_number}−#{DateTime::now}","w")

 results = []
 at_exit {
	results.each{ |result| file.puts(YAML::dump(result))}
	file.close
 }

 binaries.each { |binary|
 	sizes.each { |size|
	task = Task::new ( "#{binary} #{size} 20" , $all.uniq )
	results.push(task.execute)
	}
 }





