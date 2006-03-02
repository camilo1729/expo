=begin
  expo-ui-engine.rb - Part of a simple ui for experiment using expo concepts.
	This include kadeploy, oar and oargrid supports plus user task
	integration

  Copyright (c) 2005  Mescal Project Team
  This program is licenced under the same licence as Kadeploy.
=end

require 'soap/rpc/driver'

class Expo_ui_client
  attr_accessor :gui, :thread

	def initialize(server_http)
		@threads= []		
		@proxy = SOAP::RPC::Driver.new(server_http,"http://grid5000.fr/expo")
		@proxy.add_method('openexperiment','name')
		@proxy.add_method('closeexperiment','sid')
		@proxy.add_method('oargridsub','sid','desc','queue','program','walltime','dir','date')
		@proxy.add_method('oargridsubasync','sid','desc','queue','program','walltime','dir','date')
		@proxy.add_method('oargridstat','sid','gridid')
		@proxy.add_method('kadeploy','sid','nodeset','env','part')
		@proxy.add_method('getkadeploy','sid','nodeset')
		@proxy.add_method('script', 'sid','program','dir','args','nodeset','opt')
		@proxy.add_method('getstdout','sid','fd')
		puts "Expo client initialized, server: #{server_http}"
	end

	def test
		puts "oarnodes #{proxy.oarnodes()}"
		#puts "oarsub_short: #{proxy.oarsub_short('12','default')}"
		#puts "oarsub: #{proxy.oarsub('120','kadeploy')}"
	end

	def launch_expe(expe)
		puts "launch #{expe.name} #{expe.state}"

		if expe.state == "Waiting"	
			expe.state = "Running"
			@threads << Thread.new() {
				run_expe(expe)
				puts "Experiment #{expe.name} finished"
			}
		end
	end

	def run_expe(expe)
		expe.sid=openexperiment(expe.name)

		taskexpe= expe[0]
		taskexpe.start
		taskexpe.initStatusView(@gui) 

		loop do
			puts "Yop expe #{expe.name} #{expe.length}  finished_tasks #{expe.finished_tasks} progress #{taskexpe.progress} "
  #			pp expe

			taskexpe.progress= 100*expe.finished_tasks/(1.0*expe.length-1)
			taskexpe.update_gui
			expe.finished_tasks = 0

			expe.each do |task|
				if task.id!=0 then
					puts "Expe:#{expe.name} task:#{task.name} type:#{task.type} id:#{task.id} dep:#{task.dependence}  tid:#{task.tid} "
					if task.state == "Completed" 
						expe.finished_tasks += 1
					end

					if task.state == "Waiting" then
						launch= false
						if (task.dependence=="0") then
							launch=  true
						else
							dep= []
							if (task.dependence=="all")then
								1.upto(task.id.to_i-1) {|i| dep.push(i.to_s) if i!=nil}
							else
								dep= task.dependence.split(",")
							end
							puts "task:#{task.name} id:#{task.id} deps:"
							l=0
							dep.each {|d|
								puts "yop #{expe.hid_tasks[d].state} l:#{l}" 
								l=l+1 if expe.hid_tasks[d].state=="Completed"
							}
							launch=true if ((dep.length==l) && (l>0))
						end

						if launch then
							task.start
							task.root= taskexpe.gui_task
							@threads << Thread.new() {execute_task(task)}
						end
					end
				end
			end

			if expe.finished_tasks == expe.length-1 then
				taskexpe.progress= 100
				taskexpe.state = "Completed" 
				taskexpe.update_gui
				break
			end

			sleep 1 
		end
	end

	def execute_task(task)
 		puts "Execute task: #{task.name}  #{task.type} #{task.id} task"
#		pp task
		task.initStatusView(@gui) 
		flag = true
    begin
      self.method(task.type)
    rescue
      puts "Sorry Type: #{task.type} doesn't exist"
  		flag = false
    end
    if flag
      self.method(task.type).call(task)
  	end

		task.update_gui
		puts "Task finished #{task.name}"	
	end

	def oarsub(task)
		puts "oarsub" 	
	end

	def openexperiment(name)
		print "openexperiment #{name} sid:"
		result=@proxy.openexperiment(name)
		sid= result.sid
		puts " #{sid} reply: #{result.replycode} #{result.replymsg} "
		sid
	end

	def closeexperiment(sid)	
		puts "closeexperiment #{sid}"
		result=@proxy.closeexperiment(sid)	
		puts "reply: #{result.replycode} #{result.replymsg}"
	end

	def oargridstat(task)
		task.progress=50
		task.update_gui

		file= File.new("./expo/#{task.name}.gid","r")
		gridid= file.gets
		file.close

		puts "oargridstat name:#{task.name} gridid:#{gridid}"

		reponse=@proxy.oargridstat(task.expe.sid,gridid)
		puts "reply: #{reponse.replycode} #{reponse.replymsg}"

		guibuffer= @gui.bufferStdout(task.tid)
		if (reponse.result.length>0) then
			puts "guibuffer"
			guibuffer.insert(reponse.result)
		end

		task.state= "Completed"
		task.progress= 100

	end

	def oargridsub(task)

		result= oargridsub_exec(task,"oargridsub")
		
		guibuffer= @gui.bufferStdout(task.tid)
		if (result.length>0) then
			puts "guibuffer"
			guibuffer.insert(result)
		end

	end

	def oargridsubasync(task)

		result= oargridsub_exec(task,"oargridsubasync")
	
 		puts "oargridsubasync name	#{task.name}, gridid #{result.gridid}"
		puts "reply: #{result.replycode} #{result.replymsg}"

		guibuffer= @gui.bufferStdout(task.tid)
		if (result.buffer.length>0) then
			puts "guibuffer"
			guibuffer.insert(result.buffer)
		end
	
		file= File.new("./expo/#{task.name}.gid","w")
		file << result.gridid.to_s
		file.close
		puts "./expo/#{task.name}.gid created"

	end

	def oargridsub_exec(task,oargridsubcmd)

		task.progress=50
		task.update_gui

	 	desc =""
		task.parameters['desc'].each  {|descline|
			cluster,d = descline.shift
			desc << cluster << ":" << d << ','
		}
		
		task.parameters['desc'] = desc.chop

		puts "cmd: #{oargridsubcmd} expe: #{task.expe.sid} desc >#{task.parameters['desc']}<"

		puts "yop program	-#{task.parameters['program']}-"

		result=@proxy.method(oargridsubcmd).call(
			task.expe.sid,
			task.parameters['desc'],
			task.parameters['queue'],
			task.parameters['program'],
			task.parameters['walltime'],
			task.parameters['dir'],	
			task.parameters['date'] 
		)

		task.state= "Completed"
		task.progress= 100
		result
	end
	
	def kadeploy(task)	
		puts "kadeploy"
		puts "nodeset #{task.nodeset}"
		sid= task.expe.sid
		nodeset_name = task.nodeset
		result=@proxy.kadeploy(
			sid,
			nodeset_name,
			task.parameters['env'],
			task.parameters['part']
		)

		puts "reply: #{result.replycode} #{result.replymsg}"

		guibuffer= @gui.bufferStdout(task.tid)

		state= ""
		fdstate= ""
		length=0
		while state != "Completed" or fdstate!="close" or length!=0 do
			puts "getkadeploy #{sid} #{nodeset_name}"

			result=@proxy.getkadeploy(sid,nodeset_name)
			state= result.state.to_s
			progress= result.progress.to_f
			nbnodes= result.nbnodes.to_f
			
			fdstate= result.fdstate
			length= result.buffer.length
			
			puts "Kadeploy: Sid: #{sid} Nodeset: #{nodeset_name} State: #{state} Progress: #{progress}"  
			puts "reply: #{result.replycode} #{result.replymsg}"

			#Update Gui
			task.state= state
			if nbnodes==0 then 
				puts "Error nbnodes= #{nbnodes}"
			end

			case state
			when "BootInit"
				task.progress= 100.0 * (progress/nbnodes)/3.0
			when "PreInstall"
				task.progress= 100.0 * 5.0/12.0
			when "Transfert"
				task.progress= 100.0 * 1.0/2.0
			when "PostInstall"
				task.progress= 100.0 * 7.0/12.0
			when "BootEnv"
				task.progress= 100.0 * (2 + (progress/nbnodes)) / 3
			when "Completed"
				task.progress= 100.0
			end
			task.update_gui
			guibuffer.insert(result.buffer)
			sleep 2
		end 

	

	end

	def script(task)
		puts "Script"
		task.progress= 50
		task.update_gui
		result=@proxy.script(
			task.expe.sid,
			task.parameters['program'],
			task.parameters['dir'],
			task.parameters['args'],
			task.nodeset,
			task.parameters['opt']
		)

		#pp result
		puts "fdbuffer: #{result.fdbuffer} reply: #{result.replycode} #{result.replymsg}"

		getbuffer(task.expe.sid,task.tid,result.fdbuffer)

		task.state= "Completed"
		task.progress= 100

	end

	def getbuffer(sid,tid,fd)
		state= ""
		length= 0
		puts "GetBuffer fd:#{fd}"
		guibuffer= @gui.bufferStdout(tid)
		while ((state != "close") || (length!=0)) do
			puts "Poy"
			result=@proxy.getstdout(sid,fd)
			state= result.state
			length= result.buffer.length
			puts "getstdout state:#{result.state} length:#{result.buffer.length} buffer: #{result.buffer}"
			puts "reply: #{result.replycode} #{result.replymsg}"

			if (result.buffer.length>0) then
				puts "guibuffer"
				guibuffer.insert(result.buffer)
			end
			sleep 1
		end
	end

end

