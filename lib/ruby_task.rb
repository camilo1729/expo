require 'rubygems'
require 'serializable_proc'
require 'taktuk'

def task_ruby(name,&block)
  p = SerializableProc.new &block
  
  #puts "returning the source code of the block"
  serialize_file="/tmp/task_#{name}-object"
  File.open(serialize_file,"wb") do |file|
    Marshal.dump(p,file)
  end

  bootstrap_file = Dir.pwd+"/bootstrap_block.rb"
  options = {:connector => 'ssh',:login => "root"}
  hosts=["192.168.56.101"]
  puts hosts
  cmd_taktuk=TakTuk::TakTuk.new(hosts,options)
  #cmd="export export GEM_HOME=~/.gem/ ; "
  cmd="ruby /tmp/bootstrap_block.rb #{serialize_file}"
  cmd_taktuk.broadcast_put[serialize_file][serialize_file]
  cmd_taktuk.broadcast_put[bootstrap_file]["/tmp/bootstrap_block.rb"]
  cmd_taktuk.broadcast_exec[cmd]
  cmd_taktuk.run!
  #cmd_taktuk.broadcast_exec[cmd]
  ### Serialize file transfer
  ### Bootstrap trasfer to run the serialized proc
  ### run the bootstrap with the serialized proc as a parameter
end

