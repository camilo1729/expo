
require 'expo'
require 'g5k_api'

task :reservation do
  reserv = ExpoEngine.new()
  reserv.site=["lille"]
  reserv.resources=["{cluster='chimint'}/nodes=4"]
  reserv.walltime = 7200
  reserv.run!
end

set :user, "cruizsanabria"
set :results, []

task :setting_up do

  Experiment.resources.each { |node|
    put node.nodefile, :target => node, :path => "/tmp/machines"
  end

end

task :tlm, :target => Experiment.resources, :repeat => 10 do
  tmp_result=run("~/tlm/run_mpi 1 400 20 10 matched /tmp/machines")
  results.push(tmp_result)
end


task :writing_results do
  File.open("test_experiment.txt","w"){ |f|
    
    results.each{ |r| 
      f.write "#{r['host_name']} #{r.duration} \n"
    }
  }
end

task :stop_reservation do
  reserv.stop!
end
