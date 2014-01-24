require 'g5k_api'

set :user, "root"
set :gw_user, "cruizsanabria"
set :resources, "MyExperiment.resources"
# set :gateway, "grenoble.g5k" # This is used when executing the experiment from outside
set :public_key, "/home/cristian/.ssh/grid5000.pub"

reserv = connection(:type => "Grid5000")
reserv.resources = { :lyon => ["nodes=1"] }
# #reserv.jobs_id = {:grenoble => 1596128}
reserv.environment = "http://public.nancy.grid5000.fr/~dlehoczky/newimage.dsc"
# reserv.walltime = 3*3600
# reserv.wait = true

task_definition_start
##### Tasks Definition #####################################


task :run_reservation do
  reserv.run!
end


### Generating password less communication

task :config_ssh do

  File.open("/tmp/config",'w+') do |f|
    f.puts "Host * 
   StrictHostKeyChecking no 
   UserKnownHostsFile=/dev/null "
  end

end

task :generating_ssh_keys do
  if check("ls /tmp/temp_keys/key") then
    run("mkdir -p /tmp/temp_keys/")
    run("ssh-keygen -P '' -f /tmp/temp_keys/key") 
  end
end

task :trans_keys do
  put("/tmp/temp_keys/","/tmp/temp_keys/",:method => "scp",:target => gateway)
  put("/tmp/config","/tmp/config",:target => gateway)
  put("/tmp/config","/root/.ssh/", :target => resources)
  put("/tmp/temp_keys/key","/root/.ssh/id_rsa", :target => resources)
  put("/tmp/temp_keys/key.pub","/root/.ssh/id_rsa.pub", :target => resources)
end 

task :copy_identity do
  resources.each{ |node|
    run("ssh-copy-id -i /tmp/temp_keys/key.pub root@#{node.name}",:target => gateway)
  }
end

### Getting the benchmark

task :get_benchmark, :target => resources do
  unless check("ls /tmp/NPB3.3.tar") then
    run("cd /tmp/; wget -q http://public.grenoble.grid5000.fr/~cruizsanabria/NPB3.3.tar")
    run("cd /tmp/; tar -xvf NPB3.3.tar")
  end
end

task :compile_benchmark_lu, :target => resources do
  compile = "export PATH=/usr/local/tau-install/x86_64/bin/:$PATH;"
  compile += "export TAU_MAKEFILE=/usr/local/tau-install/x86_64/lib/Makefile.tau-papi-mpi-pdt;"
  compile += "make lu NPROCS=8 CLASS=A MPIF77=tau_f90.sh -C /tmp/NPB3.3/NPB3.3-MPI/"
  run(compile)
end

## Generating machinefile
task :transfering_machinefile do
  put(resources.nodefile,"/tmp/nodefile.txt",:target => gateway)
  put("/tmp/nodefile.txt","/tmp/machinefile", :target => resources.first)
end

task :creating_trace_dir, :target => resources do
  run("mkdir -p /tmp/mpi_traces") 
end

task :run_mpi do
  mpi_params = "-x TAU_TRACE=1 -x TRACEDIR=/tmp/mpi_traces -np 8 -machinefile /tmp/machinefile"
  run("/usr/local/openmpi-1.6.4-install/bin/mpirun #{mpi_params} /tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.8",:target => resources.first)
end 

## Gathering traces and merging
task :gathering_traces, :target => resources.first do 
  resources.each{ |node|
    run("scp -r #{node.name}:/tmp/mpi_traces/* /tmp/mpi_traces")
  }
  cmd_merge = "export PATH=/usr/local/tau-install/x86_64/bin/:$PATH;"
  cmd_merge += "cd /tmp/mpi_traces/; tau_treemerge.pl"
  run(cmd_merge)
  run("cd /tmp/mpi_traces/; /usr/local/akypuera-install/bin/tau2paje tau.trc tau.edf 1>lu.A.8.paje 2>tau2paje.error")
end

task :get_traces do
  get("/tmp/mpi_traces/lu.A.8.paje","/tmp/",:target => resources.first)
  get("/tmp/lu.A.8.paje","/tmp/",:target => gateway)
end
