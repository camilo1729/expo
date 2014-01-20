
require 'expo'
require 'g5k_api'


task :reservation do
  reserv = ExpoEngine.new()
  reserv.site = ["lille","grenoble"]
  reserv.resources = ["nodes=3","nodes=4"]
  reserv.walltime = 3600
  reserv.run!
end

set :results, nil

task :simple_task, :target => Experiment.resources do
  results = run("hostname")
end

task :printing_results do
  results.each { |r| puts r.duration}
  puts "mean : " + results.mean_duration
end

task :stoping do
  reserv.stop!
end


