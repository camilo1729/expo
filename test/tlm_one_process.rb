require 'g5k_api'
 base_url = "http://public.grenoble.grid5000.fr/~cruizsanabria/"
 environment = "tlm_simulation.env"
g5k_init(
        :site => ["lille"],
        :resources => ["nodes=1"],
        :walltime => 21*3600,
        :no_cleanup => true,
	:name => "TLM_code"                      # don't delete the experiment after the test is finished
  )
g5k_run


$ssh_user="cruizsanabria"
copy $all.uniq.node_file, $all.first, :path=> "~/Applications/TLMME_multimode/tlm/nodes.deployed"
### deactivating the ib0 interface


id, res = task $all.first, "~/Applications/TLMME_multimode/tlm/lancer_grid 1 30869 192 5610 2500 1 sc > monitor.txt"






