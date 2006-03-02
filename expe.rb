require 'yaml'
require 'pp'

NAME, TYPE, ID, DEP, PROGRESS, TIME, STEP, STATE, ACTION, TID = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
NAME_INFO, VALUE_INFO, EDITABLE_INFO = 0, 1, 2
EXPE_NAME_COLUMN, EXPE_ID_COLUMN,  EXPE_INDEX_COLUMN = 0, 1, 2

NAME_INFO_ARRAY= ["Name","Type","Id","Dependence","NodeSet"]

class Task
	attr_reader :expe, :time_start, :elapsed_time
	attr_accessor :name, 
								:type, 
								:id, 
								:dependence, :action, :parameters, :state, :nodeset, :progress, :tid, :gui_task, :root, :index

	def initialize(type,expe)
		@type= type
		@expe= expe
		@state= "Waiting"
		@progress=0
		@parameters= Hash.new
		@root=nil
	end

	def start
		@state= "Running"
		@time_start=  Time.new
	end

	def initStatusView(gui)
		@gui= gui
		@gui_task= @gui.append_taskStatus(root)
	 	update_gui
	end

	def update_gui
		puts "update_gui name: #{@name} state: #{@state} progress #{@progress}"
		@gui_task[NAME]=  @name
		@gui_task[TYPE]= @type
		@gui_task[ID]= @id
		@gui_task[DEP]= @dependence
		@gui_task[PROGRESS]= @progress.to_i
		@gui_task[STEP]= @state
		if @state=="Completed" then
			@gui_task[STATE]= @gui.icon_ok
			@gui_task[ACTION]= @gui.icon_remove
		elsif @state=="Error" then
			@gui_task[STATE]= @gui.icon_no
			@gui_task[ACTION]= @gui.icon_remove
		else
			@gui_task[STATE]= @gui.icon_yes
			@gui_task[ACTION]= @gui.icon_play
		end
	@gui_task[TID]= @tid
	@elapsed_time = Time.new-@time_start
	time = @elapsed_time.to_i
	@gui_task[TIME]=time.to_s+"s"
	end

end

class Experiment < Array
  attr_reader :name, :id
	attr_accessor :state, :finished_tasks, :hid_tasks, :sid
	def initialize(name,id)
		@name= name
		@id=id
		@state= "Waiting"
		@finished_tasks= 0
		@hid_tasks= Hash.new
	end
end

class ListExperiment < Array
	
	def initialize(file,listTask)
		puts "Load #{file} Experiment description file TODO"	

		yaml = YAML::load(File.open(file))
#		pp yaml
		id=0
		tid=0
		expe=nil
		yaml.each_with_index {|i,index|
			key,h = i.shift
			if key=="experiment"
				puts "name expe #{h["name"]}"
				expe = Experiment.new(h["name"],self.length)
				self << expe
				id=0
				t= Task.new(key,expe)
				expe << t
				listTask << t
				t.index= listTask.length-1
				print "INDEX #{t.index}"

				t.name= h["name"]
				t.type= "experiment"
				t.id= id.to_s
				t.tid= tid.to_s
				t.dependence="0"
				tid= tid + 1
				id= 1
			else
				puts "Task #{key}"
				t= Task.new(key,expe)
				self.last << t
				listTask << t
				t.index= listTask.length-1	
				print "INDEX #{t.index}"
				t.name= key
				t.id= id.to_s
				t.tid= tid.to_s
				id= id + 1
				tid= tid + 1
				t.nodeset= "default"
				t.dependence="0"
				h.each {|key,val|
			#		puts "key/val: #{key},#{val}"
					case key
					when "name"
						t.name= val 
					when "id"
						t.id= val.to_s
						self.last.hid_tasks[val]= t
					when "nodeset"
						t.nodeset= val
					when "dep"
						t.dependence= val
					else
						t.parameters[key]=val
					end
				}
			end
		}
	end

end

#listExp = ListExperiment.new("fichier_todo_yaml")
#pp listExp

