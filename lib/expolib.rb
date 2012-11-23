require 'shellwords'
## Two treat cmdline 
module Expo



class ExpoResult < Array

## Calculate the mean elapsed time for the task set.
  def mean_duration
    sum = 0
    time = 0
    self.each { |t| sum += t.duration }
    time = sum / self.length if self.length > 0
    return time
  end

## Calculate the elapsed time of task set.
  def duration
    min=Time::now()
    max=Time.local(1986, 7, 17)
    self.each do |t|
      min=t['start_time'] if t['start_time']<min
      max=t['end_time'] if t['end_time']>max
    end
    return max-min
  end

end

class TaskResult < Hash
  def duration
    return self['end_time'] - self['start_time']
  end
  
end

class String
  ## This fuction open a file an dumps the content of a variable in it.
  def to_file ( file_name )
    File.open(file_name, 'w') do |file| file.puts self end
  end
end

########## Logging ###########################

#### loggin' tasks #############
# [ <LogActor> ] [ <LogSubject> ] <LogMessage>
# [ Task:ID ] [ Action ] Message
def log_task(command,result_with_id,type)
  
  id = result_with_id[0]
  result=result_with_id[1]
  ### looking for the state of the task executed
  task_log_msg="[ #{type} Task:#{id} ] "

  result.each{ |indv|
    if indv['status'] !="0" then
      $client.logger.error  task_log_msg +" [ Error executing ] #{command} " 
      $client.logger.error  task_log_msg +" [ On Node ] #{indv['host_name']} "
      $client.logger.error  task_log_msg +" [ Elapsed Time ] #{indv.duration} secs"
      $client.data_logger.error task_log_msg 
      $client.data_logger.error command
      $client.data_logger.error indv
    else
      $client.logger.info  task_log_msg+" [ Executed ]   #{command} " 
      $client.logger.info  task_log_msg+" [ On Node ]  #{indv['host_name']} "
      $client.logger.info  task_log_msg+" [ Elapsed Time ] #{indv.duration} secs"
      $client.data_logger.info task_log_msg
      $client.data_logger.info command
      $client.data_logger.info indv
    end
  }
  
end

####### logging File managment ################

def log_file_mgt(file,result_with_id,type)
  id = result_with_id[0]
  result=result_with_id[1]
  file_log_msg = "[ #{type} File:#{id} ] "
  
  # Note status for this case if a Int but when the output is parsed from
  # taktuk wrapper is a String
  if result['status'] != 0 then
    $client.logger.error file_log_msg+" [ Error with File ] #{file} "
    $client.logger.error file_log_msg+" [ On Node ] #{result['host_name']} "
    $client.logger.error file_log_msg+" [ Elapsed Time ] #{result.duration} secs"
    $client.data_logger.error file_log_msg
    $client.data_logger.error file
    $client.data_logger.error result
  else
    $client.logger.info file_log_msg+" [ File Success ] #{file} "
    $client.logger.info file_log_msg+" [ On Node ] #{result['host_name']} "
    $client.logger.info file_log_msg+" [ Elapsed Time ] #{result.duration} secs"
    $client.data_logger.info file_log_msg
    $client.data_logger.info file
    $client.data_logger.info result

  end
end


## Treat the task which is a Sring in order to sperate it into path, exec, cmdline params.

def treat_task task
  ### here we split task into three things: PATH and executable and cmdline parameters.
  ### This is done to avoid path errors.
  # Separating path/executable and cmdline parameters
  # Dont leave any space at the begining
  temp=task.shellsplit
  exec_with_path=temp.shift
  params=temp.join(" ") unless temp.empty? 
  
  path=File.dirname(exec_with_path)
  exec=File.basename(exec_with_path)
  ## if task does not have path it is because is a command in the path
  exec ="./#{exec}" unless ( path==".")
  ##### would be this option optional ? ####################

  return [path, exec, params]
end

### Starting Definitions of functions that belongs to the DSL of expo

## Fix me #######
###  task with simple ssh. It is logged as a file operation
def simpletask(location,task)
  path,exec,params = treat_task task
  cmd = "ssh -o \"ConnectTimeout 10\""
  #cmd += " lig_expe@#{location}"
  cmd += " #{location}"
  cmd += "'cd #{path} ; #{exec} #{params}'"
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  final_result = make_task_result(command_result["command_number"])

  log_file_mgt(exec,final_result,"Simple Task")
  return final_result
end


def task(*task_params)
## task_params has to have the location in the fist position and the task in the second
  if task_params.length == 1 then
    location="localhost"
    task=task_params[0]
  else
    location=task_params[0]
    task=task_params[1]
  end
  
  path,exec,params = treat_task task
  ### we have to separate the local and remote-parallel executions.
  if location.kind_of?(Resource)
    cmd = "ruby taktuk2yaml.rb -s"
    cmd += $ssh_connector
    cmd += " -l #{$ssh_user}" if !$ssh_user.nil?
    cmd += " -t #{$ssh_timeout}" if !$ssh_timeout.nil?
    cmd += " -m #{location}"
    cmd += " b e [ 'cd #{path} ; #{exec} #{params}' ]"
  else
      cmd= "cd #{path} ; #{exec} #{params}"
  end

  command_result = $client.asynchronous_command(cmd)
  command_number = command_result["command_number"]
  $client.command_wait(command_number,1)

  final_result = (location.kind_of?(Resource) ? make_taktuk_result (command_number) : make_task_result(command_number))

  location.kind_of?(Resource) ? log_task(exec,final_result,"Sequential") : log_file_mgt(exec,final_result,"Sequential")

  # $client.data_logger.info cmd
  return final_result

end

def atask(*task_params)
#### task_params has to have the location in the first
  if task_params.length == 1 then
    location="localhost"
    task=task_params[0]
  else
    location=task_params[0]
    task=task_params[1]
  end
  
  path,exec,params = treat_task task

  if location == "localhost"
    cmd= "cd #{path} ; #{exec} #{params}"
  else
  #cmd = "taktuk2yaml -s"
    cmd = "ruby taktuk2yaml.rb -s"
    cmd += $ssh_connector
    cmd += " -l #{$ssh_user}" if !$ssh_user.nil?
    cmd += " -t #{$ssh_timeout}" if !$ssh_timeout.nil?
    cmd += " -m #{location}"
    cmd += " b e [ 'cd #{path} ; #{exec} #{params}' ]"
  end
  #----to create an asynch cmd we use generic cmd BUT! we don't wait
  #    till it finishes and continue execution of main process. In case
  #    of asynch cmd, response will contain only cmd id number
  command_result = $client.asynchronous_command(cmd)
  #----means only one atask can be inside this block at a time
  $atasks_mutex.synchronize {
    #----register our asynch cmd with provided params
    $atasks[command_result["command_number"]] = { "location" => location , "task" => task }
  }

end


def ptask(targets, task)
  
  path,exec,params = treat_task task
  #cmd = "ruby taktuk2yaml.rb --connector /usr/bin/oarsh -s"
  cmd = "ruby taktuk2yaml.rb -s"
  cmd += $ssh_connector
  #----means that 'location' node will start all other nodes. For
  #----details see 2.2.2 section of Taktuk manual
  cmd += " -m #{targets.gateway}"
  cmd += " -[ -l $ssh_user "
  targets.flatten(:node).each(:node) { |node|
    cmd += " -m #{node}"
  }
  cmd += " downcast exec [ 'cd #{path} ; #{exec} #{params}' ]"
  cmd += " -]"
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  #----here we return two values: id of a command and a hash 'res' where
  #----all the info about the command is stored
  final_result = make_taktuk_result(command_result["command_number"])
  log_task(exec,final_result,"Parallel")

  return final_result
end


def put( file, destination, params = {} )

  if params[:path] then
    path = params[:path]
  else
    path = file
  end
  $ssh_user="root" if $ssh_user.nil?  ### temporary user manage
  cmd = "scp "
  #cmd += $scp_connector # == -o StrictHostKeyChecking=no
  cmd += " "
  #here we have params[:location]==localhost for use_case_1_1.rb
  #cmd += "#{params[:location]}:" if ( params[:location] && ( params[:location] != "localhost" ) )
  cmd += "#{file} "
  cmd += "#{$ssh_user}@"
  cmd += "#{destination}:" if ( destination.to_s != "localhost" )
  cmd += "#{path}"
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  final_result = make_task_result(command_result["command_number"])

  log_file_mgt(file,final_result,"PUT")
  return final_result
end


def get( file, source, params = {} )

  if params[:path] then
    path = params[:path]
  else
    path = file
  end
  $ssh_user="root" if $ssh_user.nil?  ### temporary user manage
  cmd = "scp "
  cmd += " "
  cmd += "#{$ssh_user}@"
  cmd += "#{source}:" if ( source.to_s != "localhost" )
  cmd += "#{file} "
  cmd += " #{path}"
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  final_result = make_task_result(command_result["command_number"])

  log_file_mgt(file,final_result,"GET")
  return final_result
end


def make_task_result(id)
  result = $client.command_result( id )
  result_rctrl = $client.command_info( id )
  r = TaskResult::new
 
  r.merge!( {#'host_name' => result['host_name'], 
           #'rank' => result['rank'], 
           'command_line' => result_rctrl['command_line'], 
           'stdout' => result['stdout'], 
           'stderr' => result['stderr'], 
           'status' => result['exit_status'], 
           'start_time' => result_rctrl['start_time'], 
           'end_time' => result_rctrl['end_time'] } 
          )
  return [id,r]
end




def make_taktuk_result( id )
  result = $client.command_result( id )

  tree = YAML::load(result['stdout'])

  res = ExpoResult::new
  tree['hosts'].each_value { |h|
    h['commands'].each_value { |x|
      r = TaskResult::new
      r.merge!( {'host_name' => h['host_name'], 
                  'rank' => h['rank'], 
                  'command_line' => x['command_line'], 
                  'stdout' => x['output'], 
                  'stderr' => x['error'], 
                  'status' => x['status'], 
                  'start_time' => x['start_date'], 
                  'end_time' => x['stop_date'] } )
      res.push(r)
    }
  }

  #----display an output of command!!!
  ### Fix me ###
  ### Error handling not implemented
  if( res[0].nil?) then
	puts "Error Contacting the node"
  else
  	#puts "Command: " + res[0]['command_line']
  	#puts "Output: "
  	if !res[0]['stdout'].nil?
    		puts res[0]['stdout']
  	end
  end

 
  return [id, res]
end


def print_taktuk_result( res )
  res.each { |r|
    puts r['host_name'] + " :"
    puts r['start_time'].to_s + " - " + r['end_time'].to_s 
    puts r['command_line'];
    puts r['stdout'];
    puts r['stderr'];
    puts
  }
end



class ParallelSection
  def initialize(&block)
    @thread_array = Array::new
    instance_eval(&block)
    @thread_array.each { |t|
      t.join
    }
  end

  def sequential_section(&block)
    t = Thread::new(&block)
    @thread_array.push(t)
  end

end

def parallel_section(&block)
  ParallelSection::new(&block)
end


def get_results(targets, file, where="~/")
    $ssh_user="root" if $ssh_user.nil?
 
    #### this function gets the results from a set of nodes. 
    ### for the moment is sequentially so it has not good performance
	
    targets.flatten(:node).each(:node) { |node|
		
    	cmd = "ssh "
    	cmd += " "
    	cmd += "#{$ssh_user}@#{node}"
    	cmd += " ls #{file} " #it looks temporary in the home directory
    	command_result = $client.asynchronous_command(cmd)
    	$client.command_wait(command_result["command_number"],1)
    	result = $client.command_result(command_result["command_number"])
    	puts cmd
    	puts result["stdout"]
    	files_to_trans = result["stdout"].split()
    	puts "Number of files to trasfer for this node: #{files_to_trans.length}"
    
    	files_to_trans.each{ |current_file|
	
        	file_base=File.basename("#{current_file}")
  		cmd = "scp "
  #cmd += $scp_connector # == -o StrictHostKeyChecking=no
  		cmd += " "
  		cmd += "#{$ssh_user}@#{node}:"
  		cmd += "#{current_file}"
  		cmd += " #{where}/#{file_base}-#{node}"
 		command_result = $client.asynchronous_command(cmd)
  		$client.command_wait(command_result["command_number"],1)
  		result = $client.command_result(command_result["command_number"])
 		puts cmd
  		puts result["stdout"]
  		puts result["stderr"]
    		}
    }
    #cmd += "
    #puts result["stderr"]
    #puts file.class
  
    ### now the file has to be brought with taktuk
  #----means that 'location' node will start all other nodes. For
  #----details see 2.2.2 section of Taktuk manual

   #files_to_trans.each{ |current_file|
    #cmd = "ruby taktuk2yaml.rb -s"
    #cmd += $ssh_connector
     #cmd += " -l #{$ssh_user}" if !$ssh_user.nil?
     #targets.flatten(:node).each(:node) { |node|

     #cmd += " -m #{node}"
     #}
     #puts "file to get #{current_file}"
     #file_base=File.basename("#{current_file}")
     #cmd += " broadcast get [ '#{current_file}' ] [ '#{where}/#{file_base}-$rank' ]"
  #cmd += " -]"
     #puts "command Executed #{cmd}"
     #command_result = $client.asynchronous_command(cmd)
     #$client.command_wait(command_result["command_number"],1)
     #result = $client.command_result(command_result["command_number"])
      #puts result["stdout"]
    #}
  #----here we return two values: id of a command and a hash 'res' where
  #----all the info about the command is stored
  #return make_taktuk_result(command_result["command_number"])

end

end
