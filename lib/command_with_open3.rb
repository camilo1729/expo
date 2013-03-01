### This is an experimental version of the wrapper with open3

require 'open3'
class Command

  attr_reader :stdout,:stdin,:stderr

  def initialize(cmd=nil,&block)
    @cmd = cmd
    @block = block
    @pid = nil ## this is used mostly for waiting for the process to finish
  end

  def run
    @stdin,@stdout,@stderr,@thread_p= Open3.popen3(@cmd)
    @pid = @thread_p[:pid] 
    #puts "@pid: #{@pid} | thread: #{thread_p[:pid]}"
  end

  def wait_dep  ### this wait funtion does not work well
    raise "Command is not running!" if @pid.nil?
    if not @status
      result = Process::waitpid2(@pid)
      pid, @status = result
    end
    [@pid,@status]
  end

  def wait
    true until @thread_p.join(1) #wait for the thread to finish
    @status = @thread_p.value
  end

end
