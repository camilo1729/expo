require './command_with_open3'

class CtrlCmd
  
  attr_reader :stdout, :stdin, :stderr
  attr_reader :start_time, :end_time

  def initialize(cmd=nil)
    @cmd = Command.new(cmd)
  end
  
  def run
    @start_time  = Time.now
    @cmd.run
    @cmd.wait
    @end_time = Time.now
    ### writing the input output
    @stdout=@cmd.stdout.readlines
    # @stdin=@cmd.stdin.readlines
    @stderr=@cmd.stderr.readlines
  end

  def run_time
    return @end_time - @start_time
  end

end
