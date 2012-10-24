require 'g5k_api'
 #base_url = "http://public.grenoble.grid5000.fr/~cruizsanabria/"
 #environment = "tlm_simulation.env"
 base_url = "http://public.lille.grid5000.fr/~malexand/"
 environment = "tlm_multimode_Hemera.dsc" 
g5k_init(
        :site => ["rennes","grenoble","nancy","lille","sophia"],
        :resources => ["nodes=1","nodes=1","nodes=1","nodes=1","nodes=1"],
        :environment => {base_url+environment => 5},
        :walltime => 4*3600,
	:deployment_max_attempts => 31	,
        :no_cleanup => true,
	:name => "TLM_code"                      # don't delete the experiment after the test is finished
  )
g5k_run


$all.uniq.gen_keys

copy $all.uniq.node_file, $all.first, :path=> "/root/nodes.deployed"

id, res = task $all.first, "./lancer_grid 1 30869 192 5610 2500 1 sc"


### desativating the ib0 interface

$all.each { |node|
		task node, "/sbin/ifconfig ib0 down"
}

require 'g5k_api'
 #base_url = "http://public.grenoble.grid5000.fr/~cruizsanabria/"
 #environment = "tlm_simulation.env"
		g5k_ini(
        :site => ["rennes","grenoble"],
        :resources => ["nodes=1","nodes=1"],
        :walltime => 4*3600,
       :name => "TLM_code"                      # don't delete the experiment after the test is finished
  )
g5k_run

