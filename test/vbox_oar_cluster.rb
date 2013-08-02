require 'vbox_manage'



vm_server = VBoxManage_set.new("test_taktuk","/tmp/kameleon/2013-06-27-15-20-18/debian-amd64.vdi",1)
vm_server.add("nic1 hostonly")
vm_server.start
vm_server.set_ip

vm_cluster = VBoxManage_set.new("test_taktuk","/tmp/kameleon/2013-06-27-15-10-48/debian-amd64.vdi",10)
vm_cluster.add("nic1 hostonly")
vm_cluster.start
vm_cluster.set_ipc
## We have to add the possibility assign a fixed ip

vms_server = vm_server.create_resource_set
vms_clients = vm_cluster.create_resource_set

set :user, "root"


## configuring OAR server

task :test_kameleon, :target => vms_server do 
  copy(#{vms_clients.nodefile},:path =>"/etc/hosts")
       vms_client.each do |vm|
         run("oarnodesetting -a -h #{vm.name}")
       end
end


