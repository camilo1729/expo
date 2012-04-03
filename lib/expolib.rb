module Expo





class ExpoResult < Array
  #def duration
  def mean_duration
    sum = 0
    time = 0
    self.each { |t| sum += t.duration }
    time = sum / self.length if self.length > 0
    return time
  end
end

class TaskResult < Hash
  def duration
    return self['end_time'] - self['start_time']
  end
end


def task(location, task)
  #cmd = "taktuk2yaml -s"
  cmd = "ruby taktuk2yaml.rb -s"
  cmd += $ssh_connector
  cmd += " -l #{$ssh_user}" if $ssh_user != ""
  cmd += " -t #{$ssh_timeout}" if $ssh_timeout != ""
  cmd += " -m #{location}"
  cmd += " b e [ #{task} ]"
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  #command_result = $client.command(cmd)

  return make_taktuk_result( command_result["command_number"] )
end

def simpletask(location,task)
  cmd = "ssh -o \"ConnectTimeout 10\""
  cmd += " lig_expe@#{location}"
  cmd += " #{task} "
  command_result = $client.asynchronous_command(cmd)
  $client.command_wait(command_result["command_number"],1)
  result = $client.command_result(command_result["command_number"])
  puts result['stdout']
  puts result['stderr']
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

def make_taktuk_result( id )
  result = $client.command_result( id )


  #----the following cut the message about job deletion
  #    so we won't have an error about unrecognized colomn in YAML::load
  #    while deploying
  ind = result['stdout'].index('[OAR_GRIDDEL]')
  if ind
    result['stdout'] = result['stdout'][0..ind-1]
  end

  tree = YAML::load(result['stdout'])

#p result.inspect
#p tree["connectors"]
#p tree

  res = ExpoResult::new
  tree['hosts'].each_value { |h|
    h['commands'].each_value { |x|
      r = TaskResult::new
      r.merge!( {'host_name' => h['host_name'], 'rank' => h['rank'], 'command_line' => x['command_line'], 'stdout' => x['output'], 'stderr' => x['error'], 'status' => x['status'], 'start_time' => x['start_date'], 'end_time' => x['stop_date'] } )
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
