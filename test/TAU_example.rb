require 'expo'
require 'g5k_api'

task :reservation do
  reserv = ExpoEngine.new()
  reserv.site = ["lille","grenoble","toulouse","reims"]
  reserv.resources = ["nodes=1"]
  reserv.name = "TAU Test"
  reserv.walltime = 7200
  reserv.environment = "http://public.grenoble.grid5000.fr/~cruizsanabria/debian_papi_tau_g5k.dsc"
  reserv.run!
end


set :default_environment, {
  'PATH' => '/root/tau-2.22-p1/x86_64/bin/:/usr/bin:/bin',
  'TAU_METRICS' => 'TIME:PAPI_L2_DCM'
}
set :results, []
set :user, "cruizsanabria"

task :setup_code, :target => Experiment.resources do
  run("wget http://public.luxembourg.grid5000.fr/~cruizsanabria/g5k_school.tar")
  run("tar -xf g5k_school.tar")
  run("make -C ~/Grid5000_school/")
end


task :analysis, :target => Experiment.resources do
  tmp_result = run("pprof -f ~/Grid5000_school/MULTI__TIME/profile.0.0.0")
  results.push(tmp_result)
end


task :writing_result do

  File.open("cache_behavior.txt","w+") do |f|
    
    [128,256,512].each{ |size|
    
      result = nil

      task :execute, :on_error => :continue, :target => Experiment.resources do
        run("~/Grid5000_school/matrix_mul #{size}")
        result = run("pprof -f ~/Grid5000_school/MULTI__TIME/profile.0.0.0")
      end
    
      result.each{ |r|
        output= result['stdout'].split("\n")
        f.puts "#{r["host_name"]}\t#{size}  "+output.pop
        f.puts "#{r["host_name"]}\t#{size}  "+output.pop
      }
    }
  end
end


task :stop_reservation do
  reserv.stop!
end
