#!/usr/bin/env ruby
=begin
  expo-ui.rb - A simple ui for experiment using expo-engine.
	This include kadeploy, oar and oargrid supports plus user tasck
	intergration

  Copyright (c) 2005  Mescal Project Team
  This program is licenced under the same licence as Kadeploy.
=end

require 'libglade2'
require 'expe'
require 'expo-ui-client'
require 'getoptlong'

class BufferStdout
	attr_accessor :buffer,:hide
	def initialize(textview)
		@buffer= Gtk::TextBuffer.new
		@textview= textview
		@start_iter, @end_iter = @buffer.bounds
    @mark = @buffer.create_mark(nil, @end_iter, false)
		@hide= true
	end
	def insert(text)
		@start_iter, @end_iter = @buffer.bounds
    @mark = @buffer.create_mark(nil, @end_iter, false)
		@buffer.insert(@end_iter,text)
		@textview.scroll_to_mark(@mark, 0, false, 0, 1) if !@hide  
	end
end

class Expo_ui

	attr_accessor :expo_client, :listExpe, :listTask, :h_stdbuffer

  def initialize(path)
    @glade = GladeXML.new(path) {|handler| method(handler)}
		@treeviewExpe = @glade["treeviewExpe"]
    @treeviewStatus = @glade["treeviewStatus"]
		@treeviewInfo = @glade["treeviewInfo"]
		@mainwidow  = @glade["window1"]
		#stdout
		@labelStdout= @glade["labelStdout"]
		@textviewStdout= @glade["textviewStdout"]
		#dialogLaunchExpe
		@dialogLaunchExpe = @glade["dialogLaunchExpe"]
		@dialogLaunchExpe.signal_connect('response') { |dialogue,reponse| dialogLaunchExpe(reponse) }
  	@dialogLaunchExpe.signal_connect('destroy') {
			puts "dialogLaunchExpe destroy !"
			@dialogLaunchExpe.hide
		} 
	  @entryLaunchExpo  = @glade["entryLaunchExpo"]
		@dialogLaunchExpe.hide
		@displayed_stdbuffer = ""
		@h_stdbuffer = Hash.new

		@name_value_info = Array.new
		@task_attr_info = Array.new

 	end
			
	def initviewStatus
#		pp @treeviewStatus
    @treeviewStatus.rules_hint=true
    @modelStatus = Gtk::TreeStore.new(String,String,String,String,Float,String,String,Gdk::Pixbuf,Gdk::Pixbuf,String)

		namerenderer = Gtk::CellRendererText.new
    namecol = Gtk::TreeViewColumn.new("Name", namerenderer,  :text => NAME)
    @treeviewStatus.append_column(namecol)

		typerenderer = Gtk::CellRendererText.new
    typecol = Gtk::TreeViewColumn.new("Type", typerenderer, :text => TYPE)
    @treeviewStatus.append_column(typecol)

		idrenderer = Gtk::CellRendererText.new
    idcol = Gtk::TreeViewColumn.new("Id", idrenderer, :text => ID)
    @treeviewStatus.append_column(idcol)

		deprenderer = Gtk::CellRendererText.new
    depcol = Gtk::TreeViewColumn.new("Dep", deprenderer , :text => DEP)
    @treeviewStatus.append_column(depcol)

		progressrenderer = Gtk::CellRendererProgress.new
    progresscol = Gtk::TreeViewColumn.new("Progress           ", progressrenderer , :value => PROGRESS)
    @treeviewStatus.append_column(progresscol)

		timerenderer = Gtk::CellRendererText.new
    timecol = Gtk::TreeViewColumn.new("Time", timerenderer , :text => TIME)
    @treeviewStatus.append_column(timecol)

		steprenderer = Gtk::CellRendererText.new
    stepcol = Gtk::TreeViewColumn.new("Step", namerenderer,  :text => STEP)
    @treeviewStatus.append_column(stepcol)

		staterenderer = Gtk::CellRendererPixbuf.new
    statecol = Gtk::TreeViewColumn.new("State", staterenderer, :pixbuf => STATE)
    @treeviewStatus.append_column(statecol)

		actionrenderer =  Gtk::CellRendererPixbuf.new
    actioncol = Gtk::TreeViewColumn.new("Action", actionrenderer, :pixbuf => ACTION)
    @treeviewStatus.append_column(actioncol)

    @treeviewStatus.set_model(@modelStatus)
    @treeviewStatus.set_size_request(600, 250)

		selection = @treeviewStatus.selection

    selection.signal_connect('changed') do |selection|
			iter = selection.selected
			if iter!=nil 
				displayStatus(iter.get_value(TID))
			end
    end
	end

	def initviewInfo
		@treeviewInfo.rules_hint=true
		@treeviewInfo.selection.mode = Gtk::SELECTION_SINGLE

    @modelInfo = Gtk::TreeStore.new(String,String,TrueClass)

		namerenderer = Gtk::CellRendererText.new
    namecol = Gtk::TreeViewColumn.new("Name", namerenderer,  :text => NAME_INFO)
    @treeviewInfo.append_column(namecol)

		valuerenderer = Gtk::CellRendererText.new
		valuerenderer.signal_connect('edited') do |*args|
  		cellInfo_edited(*args.push(@modelInfo))
    end

		@treeviewInfo.insert_column(-1, 'Value', valuerenderer,
			{
				:text => VALUE_INFO,
			  :editable => EDITABLE_INFO,
			})

 	 	@treeviewInfo.set_model(@modelInfo)

		NAME_INFO_ARRAY.each do |name|	
			@name_value_info << @modelInfo.append(nil)
			@name_value_info.last[NAME_INFO]= name
			@name_value_info.last[VALUE_INFO]= "-"
			@name_value_info.last[EDITABLE_INFO]= true 
		end

		(1..10).each do |i|
			@name_value_info << @modelInfo.append(nil)
			@name_value_info.last[EDITABLE_INFO]= true 
		end

	end

 	def cellInfo_edited(cell, path_string, new_text, model)

  	path = Gtk::TreePath.new(path_string)
  	iter = model.get_iter(path)

		i = iter.path.indices[0]
		name = @task_attr_info[i]
		value = new_text
		puts "New value: #{value}"
 		iter.set_value(VALUE_INFO, value)

		if name.class == Fixnum
			cluster,attr_submit = value.split("->") 
			puts "desc to update #{cluster} #{attr_submit}"	
			adesc = @task_info.parameters["desc"]
			h_desc_cluster = adesc[name]
			h_desc_cluster[cluster] = attr_submit
		else
			if NAME_INFO_ARRAY.include?(name)
				@task_info.instance_variable_set("@"+name.downcase, value)
			else
				@task_info.parameters[name] = value
			end
		end
		pp @task_info

		#update attribut
		#first task attribut
		#second task parameter
  end


	def bufferStdout(tid)
		buffer= BufferStdout.new(@textviewStdout)
		@h_stdbuffer[tid]= buffer
		buffer
	end

	def append_taskStatus(root)
		@modelStatus.append(root)
	end

	def icon_yes
		@mainwidow.render_icon(Gtk::Stock::YES, Gtk::IconSize::BUTTON, "")
	end

	def icon_no
		@mainwidow.render_icon(Gtk::Stock::NO, Gtk::IconSize::BUTTON, "")
	end

	def icon_ok
		@mainwidow.render_icon(Gtk::Stock::OK, Gtk::IconSize::BUTTON, "")
	end

	def icon_play
		@mainwidow.render_icon(Gtk::Stock::MEDIA_PLAY, Gtk::IconSize::BUTTON, "")
	end

	def icon_remove
		@mainwidow.render_icon(Gtk::Stock::REMOVE, Gtk::IconSize::BUTTON, "")
	end

 	def initviewExpe(listExpe)
		@treeviewExpe.rules_hint=true
		@modelExpe = Gtk::TreeStore.new(String,String,Integer)

		namerenderer = Gtk::CellRendererText.new
		namecol = Gtk::TreeViewColumn.new("Experiment", namerenderer, {:text => EXPE_NAME_COLUMN})
    @treeviewExpe.append_column(namecol)
	
		idrenderer = Gtk::CellRendererText.new
		idcol = Gtk::TreeViewColumn.new("Id", idrenderer, {:text => EXPE_ID_COLUMN})
    @treeviewExpe.append_column(idcol)

		@treeviewExpe.set_model(@modelExpe)

		selection = @treeviewExpe.selection

    selection.signal_connect('changed') do |selection|
			iter = selection.selected
			if iter!=nil 
				displayInfo(iter.get_value(EXPE_INDEX_COLUMN))
			end
    end
      
		@treeviewExpe.signal_connect('row_activated') do |tree_view, path, column|
        row_activated_Expe(tree_view.model, path)
    end

    @treeviewExpe.set_size_request(200, 200)

#fill tree
		listExpe.each { |expe|
			root = @modelExpe.append(nil)
			root.set_value(EXPE_NAME_COLUMN, expe.name)
			root[EXPE_INDEX_COLUMN] = expe[0].index
			expe.each { |task|
				if task.type != "experiment"
					expe_or_task =@modelExpe.append(root)
					expe_or_task[EXPE_NAME_COLUMN] = task.name
					expe_or_task[EXPE_ID_COLUMN] = task.id
					expe_or_task[EXPE_INDEX_COLUMN] = task.index
				end
			}
		}

  end

	def displayInfo(expe_task_index)
		puts "display info #{expe_task_index}"
	
		task = 	@listTask[expe_task_index]
		@task_info = task		
		i=0
		NAME_INFO_ARRAY.each do |name|
			value = "-"
			begin
				value = task.instance_variable_get("@"+name.downcase)
			rescue
				puts "task.#{name.downcase} doesn't exist !"
				value = "-"
			end
			@name_value_info[i][VALUE_INFO] = value
			@task_attr_info[i] = name 
			i = i + 1	
		end

		task.parameters.each do |name,value|
			if name == "desc"
				value.each_with_index do |val,index|
					@name_value_info[i][NAME_INFO] = name
					aval = val.to_a 
					@name_value_info[i][VALUE_INFO] = "#{aval[0][0]}->#{aval[0][1]}"
					@task_attr_info[i] = index
					i = i + 1
				end 
			else	
				@name_value_info[i][NAME_INFO] = name 
				@name_value_info[i][VALUE_INFO] = value
				@task_attr_info[i] = name
				i = i + 1
			end
		end
		
		(i..i+10).each do |l|
			if @name_value_info[l] != nil 
				@name_value_info[l][NAME_INFO] = "" 
				@name_value_info[l][VALUE_INFO] = ""
				@task_attr_info[l] = nil
			end
		end
	end

	def displayStatus(tid)
		puts "Display status/stdout task_tid: #{tid}"

		@h_stdbuffer[@displayed_stdbuffer].hide= true	if @h_stdbuffer.has_key?(@displayed_stdbuffer)

		if @h_stdbuffer.has_key?(tid) then
			@textviewStdout.buffer= @h_stdbuffer[tid].buffer
			@h_stdbuffer[tid].hide= false
			@labelStdout.text= "Stdout: TEST"
			@displayed_stdbuffer= tid
		else
			puts "Non buffer available for task_tid: #{tid}"
		end			
	end

	def row_activated_Expe(modelExpe,path) 
		iter = modelExpe.get_iter(path)
		name = iter.get_value(EXPE_NAME_COLUMN)
		@entryLaunchExpo.text = name
		puts "dialogLaunchExpe.show #{name}"
		@dialogLaunchExpe.show 
	end

	def dialogLaunchExpe(reponse)
		if reponse == Gtk::Dialog::RESPONSE_OK
			puts "Launch expe #{@entryLaunchExpo.text}"
			index_expe = @listExpe.each_with_index  { |expe,i|
				if expe.name == @entryLaunchExpo.text 
					break i
				end
			}
			#Launch expe
			@expo_client.launch_expe(@listExpe[index_expe])
		end

  	@dialogLaunchExpe.hide
	end

	def on_new1_activate
	end

	def on_open1_activate
	end

	def on_save_as1_activate
	end

	def on_quit1_activate
	end

	def on_cut1_activate
	end

	def on_copy1_activate 
	end

	def on_paste1_activate
	end

	def on_about1_activate
	end

	def on_save1_activate
	end

	def on_delete1_activate
	end

end


opts = GetoptLong.new(
  [ "--dev",      "-d",          GetoptLong::NO_ARGUMENT ],
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

if opt_hash.has_key?('--dev')
  $dev=true
end

Gtk.init

server = "http://localhost:12321"

gui = Expo_ui.new("expo-ui.glade")

fileexpe = ARGV[0]||"expo.yaml"

listTask = Array.new

listExp = ListExperiment.new(fileexpe,listTask)
pp listExp


expo_client = Expo_ui_client.new(server)

gui.expo_client = expo_client
gui.listExpe = listExp
gui.listTask = listTask


expo_client.gui = gui #necessaire ?

gui.initviewStatus
gui.initviewInfo
gui.initviewExpe(listExp)
#gui.testview
Gtk.main
