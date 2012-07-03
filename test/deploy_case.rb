require 'g5k_api'
 base_url = "http://public.grenoble.grid5000.fr/~cruizsanabria/"
 environment = "oarnode.env"
 g5k_init(
        :site => ["lille"],
        :resources => ["nodes=2"],
        :environment => {base_url+environment => 2},
        :walltime => 1800,
	:deployment_max_attempts => 2,
        :no_cleanup => true                       # don't delete the experiment after the test is finished
  )
g5k_run


