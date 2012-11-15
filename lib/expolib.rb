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

#### loggin' tasks #############

def log_task(command,result,id)
  ### looking for the state of the task executed
  result.each{ |indv|
    if indv['status'] !="0" then
      $client.logger.error "Error in Task [ #{command} ] on node [ #{indv['host_name']} ] with ID #{id}"
      $client.data_logger.error command
      $client.data_logger.error indv
    else
      $client.logger.info "Task Executed [ #{command} ] on node [ #{indv['host_name']} ] with ID #{id}"
      $client.data_logger.info command
      $client.data_logger.info indv
    end
  }
  
end


### Starting Definitions of functions that belongs to the DSL of expo

def task(location, task)

  ### here we split task into two things: PATH and executable with cmdline parameters.
  ### This is done to avoid path errors.
  dir_path=File.dirname(task)
  exec_with_params=File.basename(task)
  ## if task does not have path it is because is a command in the path
  exec_with_params="./#{exec_with_params}" unless dir_path=="."
  ##### would be this option optional ? ####################


  cmd = "ruby taktuk2yaml.rb -s"
  cmd += $ssh_connector
  cmd += " -l #{$ssh_user}" if !$ssh_user.nil?
  cmd += " -t #{$ssh_timeout}" if !$ssh_timeout.nil?
  cmd += " -m #{location}"
  cmd += " b e [ 'cd #{dir_path} ; #{exec_with_params}' ]"

  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  final_result = make_taktuk_result( command_result["command_number"] )

  log_task(exec_with_params,final_result[1],final_result[0])
  # $client.data_logger.info cmd
  return final_result

end

def atask(location, task)
  #cmd = "taktuk2yaml -s"
  cmd = "ruby taktuk2yaml.rb -s"
  cmd += $ssh_connector
  cmd += " -l #{$ssh_user}" if !$ssh_user.nil?
  cmd += " -t #{$ssh_timeout}" if !$ssh_timeout.nil?
  cmd += " -m #{location}"
  cmd += " b e [ #{task} ]"
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

def simpletask(location,task)
  cmd = "ssh -o \"ConnectTimeout 10\""
  #cmd += " lig_expe@#{location}"
  cmd += " #{location}"
  cmd += " #{task} "
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  result = $client.command_result(command_result["command_number"])
  puts result['stdout']
  puts result['stderr']
  return result
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

def ptask(location, targets, task)
  #cmd = "ruby taktuk2yaml.rb --connector /usr/bin/oarsh -s"
  cmd = "ruby taktuk2yaml.rb -s"
  cmd += $ssh_connector
  #----means that 'location' node will start all other nodes. For
  #----details see 2.2.2 section of Taktuk manual
  cmd += " -m #{location}"
  cmd += " -["
  targets.flatten(:node).each(:node) { |node|
    cmd += " -m #{node}"
  }
  cmd += " downcast exec [ #{task} ]"
  cmd += " -]"
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  #----here we return two values: id of a command and a hash 'res' where
  #----all the info about the command is stored
  return make_taktuk_result(command_result["command_number"])
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


def copy( file, destination, params = {} )
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
  result = $client.command_result(command_result["command_number"])
  puts cmd
  puts result["stdout"]
  puts result["stderr"]
  puts
end



def make_taktuk_result( id )
  result = $client.command_result( id )

  tree = YAML::load(result['stdout'])

#p result.inspect
#p tree["connectors"]
#p tree

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
  if( res[0].nil?) then
	puts "Error Contacting the node"
  else
  	puts "Command: " + res[0]['command_line']
  	puts "Output: "
  	if !res[0]['stdout'].nil?
    		puts res[0]['stdout']
  	end
  end

 
  return [id, res]
end
		
end
