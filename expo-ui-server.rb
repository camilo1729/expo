#!/usr/bin/env ruby

require 'soap/rpc/standaloneServer'
require 'yaml'
require 'monitor'
require 'pty'
require 'expect'
require 'getoptlong'

include SOAP::Mapping

$expect_verbose = true

OK,KO= 200,500

NS = 'http://grid5000.fr/expo'

#Some constants
SSH 					= 'ssh'


#	OARGRIDSUB    = "oargridsub"
#	OARGRIDSTAT   = "oargristat"
#	KADEPLOY			= "kadeploy"

#	OARGRIDSUB    = "./fakeoargridsub"
#	OARGRIDSTAT   = "./fakeoargridstat"
#	KADEPLOY      = "./fakekadeploy"

  OARGRIDSUB    = "/usr/local/bin/oargridsub"
  OARGRIDSTAT   = "/usr/local/bin/oargridstat"
  KADEPLOY      = "/usr/local/bin/kadeploy"


	KADEPLOY_FRONTAL = { 
								'idpot' => 'oar.idpot.grenoble.grid5000.fr',
        				'azur' => 'oar.sophia.grid5000.fr',
        				'parasol' => 'oar.parasol.rennes.grid5000.fr',
        				'gdx' => 'oar.orsay.grid5000.fr',
        				'toulouse' => 'oar.toulouse.grid5000.fr',
        				'paraci' => 'oar.paraci.rennes.grid5000.fr',
        				'bordeaux' => 'oar.bordeaux.grid5000.fr',
        				'icluster2' => 'oar.icluster2.grenoble.grid5000.fr',
        				'tartopom' => 'oar.tartopom.rennes.grid5000.fr',
       					'lyon' => 'oar.lyon.grid5000.fr',
								'lille' => 'oar.lille.grid5000.fr',
								'grillon' => 'oar.nancy.grid5000.fr',
								'localhost' => 'localhost'
							}

class ExperimentServer
	attr_accessor :name, :sid, :state, :nodesets, :gridId, :kadeploy, :afdbuffer, :allnodes
	def initialize(name)
		@name= name
		@state= "waiting"
		@allnodes= Array.new
		@nodesets= Hash.new
		@kadeploy= Hash.new
		@kadeploy.extend(MonitorMixin)
		@afdbuffer= Array.new
		@afdbuffer.extend(MonitorMixin)
	end 

	
	def create_filenode
		@nodesets.each { |name,nodeset|
			nodeset.create_filenode
		}
  end	

	def close
		puts "TODO"
	end
end

class NodeSet
	attr_accessor :name, :cluster, :jobId, :nodes, :filenode, :frontal, :sid

	def initialize(name,cluster,jobId,sid)
		@name= name
		@cluster= cluster
		@frontal= KADEPLOY_FRONTAL[cluster]
		@jobId= jobId
		@sid=sid
		@nodes=[]
		@filenode= "/tmp/" + @name + '_' + @sid.to_s + '_' + ENV["USER"] 
	end

	def create_filenode
			file= File.new(@filenode,"w")
			@nodes.each {|node|
				file << node << "\n"
			}
			file.close
			puts "scp #{@filenode} #{@frontal}:#{@filenode}"
			`scp #{@filenode} #{@frontal}:#{@filenode}` if cluster!="localhost"
	end

end

class FdBuffer
	attr_accessor :state,:buffer
	def initialize
		@state= "open"
		@mutex= Mutex.new
		@buffer= String.new 
	end
  def put(buffer)
		@mutex.synchronize {@buffer << buffer}
	end
	def get
		@mutex.synchronize {@buffer.slice!(0..@buffer.length)}		
	end
end

class Deploy 
	attr_accessor :state, :nodeset, :progress, :nbnodes, :sid, :env, :part
	attr_reader :fd
	
	def initialize(sid,nodeset,env,part,fd)
		@sid= sid
		@nodeset= nodeset
		@env= env
		@part= part
		@state= ""
		@progress= 0
		@nbnodes= nodeset.nodes.length
		@fd= fd
		@mutex=Mutex.new
		puts "deploy init #{sid} #{nodeset} nbnodes #{@nbnodes} "
	end

	def update(state,progress)
		@mutex.synchronize do
			@state= state
			@progress= progress 
		end
	end

	def get
		@mutex.synchronize {[@state,@progress,@nbnodes]} 
	end

end

class SimpleReponse
	attr_accessor :replycode, :replymsg
	def initialize(reply_code, reply_msg)
		@replycode = reply_code
		@replymsg = reply_msg
	end
end


class ResultReponse
	attr_accessor :result, :replycode, :replymsg
	def initialize(result, reply_code, reply_msg)
		@result = result
		@replycode = reply_code
		@replymsg = reply_msg
	end
end


class OpenReponse
	attr_accessor :sid, :replycode, :replymsg
	def initialize(sid,reply_code,reply_msg)
		@sid = sid
		@replycode = reply_code
		@replymsg = reply_msg
	end
end

class ScriptReponse
	attr_accessor :fdbuffer, :replycode, :replymsg
	def initialize(fdbuffer,reply_code,reply_msg)
		@fdbuffer= fdbuffer
		@replycode = reply_code
		@replymsg = reply_msg
	end
end


class OargridsubasyncReponse
	attr_accessor :gridid, :buffer, :replycode, :replymsg 
	def initialize(gridid,buffer,reply_code,reply_msg)
		@gridid= gridid
		@buffer= buffer
		@replycode = reply_code
		@replymsg = reply_msg
	end
end

class GetKadeployReponse
	attr_accessor :state, :progress, :nbnodes,  :state, :buffer, :replycode, :replymsg
	def initialize(state,progress,nbnodes,fdstate,buffer,reply_code,reply_msg)
		@state= state
		@progress= progress
		@nbnodes= nbnodes
		@fdstate= fdstate
		@buffer= buffer
		@replycode = reply_code
		@replymsg = reply_msg
	end
end

class FdStdOutReponse
	attr_accessor :state, :buffer, :replycode, :replymsg
	def initialize(state,buffer,reply_code,reply_msg)
		@state= state
		@buffer= buffer	
		@replycode = reply_code
		@replymsg = reply_msg
	end
end

class ExpoExec
 attr_accessor :thread

	def initialize
		puts  "Init ExpoExec"
		@listExpe= []
		@indexpe= []
		@threads= []
		@listExpe.extend(MonitorMixin)
		@threads.extend(MonitorMixin)		
	end

	def openexperiment(name)
		puts "poy"
		expe = ExperimentServer.new(name)
		@listExpe.synchronize do
			@listExpe << expe
			expe.sid = @listExpe.length-1
		end
		puts "Open Experiment #{name} sid: #{expe.sid}"
		puts "Name #{@listExpe.last.name}"
		reponse = OpenReponse.new(expe.sid,200,"OK")
		return reponse
	end

	def closeexperiment(sid)
		puts "Close Experiment #{sid}  #{@listExpe[sid].name}" 
		@listExpe.synchronize do
			@listExpe[sid].close
		end
		reponse = SimpleReponse.new(200,"OK")
		return reponse
	end

	def oargridsub(sid,desc,queue,program,walltime,dir,date)

		gridid,buffer= oargridsub_exec(sid,desc,queue,program,walltime,dir,date)

		buffer << oargridstat_exec(sid,gridid)

	end

	def oargridsubasync(sid,desc,queue,program,walltime,dir,date)
		gridid,buffer= oargridsub_exec(sid,desc,queue,program,walltime,dir,date)
		reponse= OargridsubasyncReponse.new(gridid.to_i,buffer,200,"OK")
		return reponse
	end

	def oargridstat(sid,gridId)
		puts "Oargridstat "
 		buffer= oargridstat_exec(sid,gridId)
		reponse = ResultReponse.new(buffer,200,"OK")
		return reponse
	end

	def kadeploy(sid,nodeset_name,env,part)
		puts "kadeploy: #{nodeset_name}, #{env}, #{part}."
		puts "listExpe #{@listExpe}"
		puts "expe sid #{sid}"
	  expe=@listExpe[sid]
		kadeploy= expe.kadeploy

		afdbuffer=expe.afdbuffer
		fd=0
		afdbuffer.synchronize do
			afdbuffer <<  FdBuffer.new
			fd= afdbuffer.length-1
		end
		puts "fd: #{fd}"

		deploy= Deploy.new(sid,expe.nodesets[nodeset_name],env,part,fd)

		kadeploy.synchronize do
			kadeploy[nodeset_name]= deploy
		end

		@threads.synchronize do
			@threads << Thread.new(deploy) {|x| kadeploy_exec(x,afdbuffer[fd])}
		end
		reponse = SimpleReponse.new(200,"OK")
 		return reponse
	end

	def oargridsub_exec(sid,desc,queue,program,walltime,dir,date)
		expe = 	@listExpe[sid]
		nodesets = expe.nodesets
		puts "oargridsub: #{desc}, #{queue},-#{program}-, #{walltime}, #{dir}, #{date}."

		cmd = ""
		cmd << OARGRIDSUB
   	cmd <<  " -p #{program}"  if (program && program != "")
		cmd <<  " -q #{queue}"    if (queue && queue  != "")
   	cmd <<  " -s \"#{date}\"" if (date  &&  date != "")
   	cmd <<  " -w #{walltime}" if (walltime  && walltime != "")
		cmd <<  " -d #{dir}"      if (dir  &&  dir != "")

    cmd <<  " #{desc}"
		gridId=0
    puts "Oargridsub command: #{cmd}"
		reject = false
		buffer= ""
		`#{cmd}`.split(/\n/).each {|x|
			buffer << x
			x =~ /^\[OAR_GRIDSUB\].*id = (\d+)$/
      if $1
        puts "Grid resa id  #$1"
        gridId = $1
				expe.gridId = gridId
      end
      if x =~ /^\[OAR_GRIDSUB\].*rejected$/
        puts "Grid reservation was rejected"
        reject = true
      end
    }
		if reject==true
			puts "ERROR TODO !!!!!!!!!!!!!!!!!!!!!!!" 
		end
    [gridId,buffer]
	end

	def oargridstat_exec(sid,gridid)
		expe = 	@listExpe[sid]
		buffer= ""
		cmd = "#{OARGRIDSTAT} #{gridid} -Y " 
		puts "Oargridstat command: #{cmd}"
		resultcmd = `#{cmd}`
		buffer << resultcmd
		yaml = YAML::load(resultcmd)
		cmdl = "#{OARGRIDSTAT} -l #{gridid} -Y -w"
		puts "Oargridstat command: #{cmdl}"
		yamlnodes = YAML::load(`#{cmdl}`)

		yaml['clusterJobs'].each { |cluster,submissionset|
			submissionset.each { |submission|
				puts "cluster #{cluster} name #{submission[1]['name']} batchId #{submission[1]['batchId']}"
				name= submission[1]["name"]
				batchId= submission[1]["batchId"]
				expe.nodesets[name]= NodeSet.new(name,cluster,batchId,sid)			
				subnodes = yamlnodes[cluster]
				nodes = subnodes[batchId]

				#unique on nodes
				uniq_nodes = Array.new()
				nodes.each { |node| uniq_nodes.push(node) if !uniq_nodes.include?(node)}

				expe.nodesets[name].nodes = uniq_nodes
				expe.allnodes.concat(nodes)
			}
		}
		expe.nodesets.each {|name,nodeset|
			puts "name #{name}/#{nodeset.name} jobId #{nodeset.jobId}  cluster #{nodeset.cluster}  node0  #{nodeset.nodes[0]}"
			nodeset.nodes.each {|node| puts "#{node}"}
		}  

		expe.nodesets["all"]= NodeSet.new("all","localhost",0,sid)
	 	expe.nodesets["all"].nodes = expe.allnodes

		expe.create_filenode
		buffer
	end

	def getkadeploy(sid,nodeset_name)
		puts "getkadeploy #{sid} nodeset #{nodeset_name}"
		expe= @listExpe[sid]
		kadeploy= expe.kadeploy
		deploy = kadeploy[nodeset_name]
		afdbuffer=expe.afdbuffer
		fdbuffer= afdbuffer[deploy.fd]
	
		buffer = fdbuffer.get

		state,progress,nbnodes= deploy.get
		if state=="" then
			state= "Running"
		end	
		puts "result getkadeploy #{state} #{progress} #{nbnodes}"
		result= GetKadeployReponse.new(state,progress.to_i,nbnodes.to_i,fdbuffer.state,buffer,200,"OK")
		return result
#	[state,progress]
	end

	def script(sid,program,dir,args,nodeset_name,opt)
		puts "script: #{program}, #{dir}, #{args}, #{nodeset_name}, #{opt}"
		expe= @listExpe[sid]
		nodeset= expe.nodesets[nodeset_name]
		afdbuffer=expe.afdbuffer
		fd=0

		afdbuffer.synchronize do
			afdbuffer <<  FdBuffer.new
			fd= afdbuffer.length-1
		end

		puts "fd: #{fd}"

		optargs=""
		if opt=="nodefilelist" then
			 optargs= "--nodefilelist "
			 expe.nodesets.each {|name,nodeset| optargs << "#{name}:#{nodeset.filenode}," if name!="all"}
			 optargs.chop!
		end
	  puts "optargs: #{optargs}"

		@threads.synchronize do
			@threads << Thread.new() {script_exec(afdbuffer[fd],program,dir,args,nodeset,optargs)}
		end
 		reponse = ScriptReponse.new(fd,200,"OK")
		return reponse   
	end

	def script_exec(fdbuffer,program,dir,args,nodeset,optargs)
		
		cmd =  ""
		cmd << SSH
		cmd << " #{KADEPLOY_FRONTAL[nodeset.cluster]}"
		cmd << " #{dir}#{program}"
		cmd << " --nodefile #{nodeset.filenode} #{optargs} #{args}"
		puts "Script command: #{cmd}" 
	
		begin	
	  	PTY.spawn cmd do |r,w,pid|
				loop do
					line= r.readline
					fdbuffer.put(line)
					puts "STDOUT: #{line}"
				end
			end
		rescue
			puts "Script Ended"
		end
		fdbuffer.state="close"
	end

	def kadeploy_exec(deploy,fdbuffer)

		nodeset= deploy.nodeset
		cmd =  ""
		cmd << SSH
		cmd << " -t #{KADEPLOY_FRONTAL[nodeset.cluster]}"
		cmd << " #{KADEPLOY}"
		cmd << " -f #{nodeset.filenode} -e #{deploy.env} -p #{deploy.part}"
		puts "Kadeploy command: #{cmd}, cluster: #{nodeset.cluster}"

		begin
    	PTY.spawn cmd do |r,w,pid|
				state=""
				while state!="Completed" do
					line= r.readline	
					fdbuffer.put(line)
					puts "STDOUT: #{line}" 
					line=~ /<(.*)>/
					if $1 then
						state,progress=$1.split(" ")
						puts "state #{state} progress#{progress}"
						deploy.update(state,progress)
					end
				end
				loop do
					line= r.readline
					fdbuffer.put(line)
		#			puts "STDOUT: #{line}"
				end
			end
		rescue
			puts "Script Ended"
		end
		fdbuffer.state="close"
	end

	def getstdout(sid,fd)
		puts "getstdout sid:#{sid}, fd:#{fd}"
		expe= @listExpe[sid]
		afdbuffer=expe.afdbuffer
		fdbuffer= afdbuffer[fd]
		buffer = fdbuffer.get
		puts "buffer: #{buffer} \n state:#{fdbuffer.state}"
		reponse= FdStdOutReponse.new(fdbuffer.state,buffer,200,"OK")
		return reponse
	end

end

class ExpoServer < SOAP::RPC::StandaloneServer
	def on_init
		puts "on_init"
		expo = ExpoExec.new
		add_method(expo,'openexperiment','name')
		add_method(expo,'closeexperiment','sid')
		add_method(expo,'oargridsub','sid','desc','queue','program','walltime','dir','date')
		add_method(expo,'oargridsubasync','sid','desc','queue','program','walltime','dir','date')
		add_method(expo,'oargridstat','sid','gridid')
		add_method(expo,'kadeploy','sid','nodeset','env','part')
		add_method(expo,'getkadeploy','sid','nodeset')
		add_method(expo,'script','sid','program','dir','args','nodeset','opt')
		add_method(expo,'getstdout','sid','fd')
	end
end

opts = GetoptLong.new(
  [ "--verbose",    "-v",        GetoptLong::NO_ARGUMENT ]
)

# process the parsed options
opt_hash = Hash.new()
opts.each do |opt, arg|
  puts "Option: #{opt}, arg #{arg}"
  opt_hash[opt] = arg
end

if opt_hash.has_key?('--verbose')
	$verbose=true
end

svr = ExpoServer.new('expo', NS, '0.0.0.0', 12321)
trap('INT') { svr.shutdown }

puts "Expo server"

svr.start
