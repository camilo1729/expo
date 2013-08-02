require 'command_with_open3'

class CtrlCmd
  
  attr_reader :stdout, :stdin, :stderr
  attr_reader :start_time, :end_time, :default_filter

  ##### Default Filter for comamnd instrumeted
  Filter = {
    :user_time=>"User",
    :system_time => "System",
    :percent_cpu => "Percent",
    :elapsed_time => "Elapsed",
    :mem_max => "Maximum resident",
    :stext_size => "Average share",
    :utext_size => "Average unshare",
    :stack_size => "Average stack",
    :total_size => "Average total",
    :mem_avg => "Average resident",
    :major_page_faults => "Major",
    :minor_page_faults => "Minor",
    :i_context_switches => "Involuntary",
    :v_context_switches => "Voluntary"
   
  }
 ## It is imcomplete so far 
  

  def initialize(cmd=nil)
    @cmd = Command.new(cmd)
    @default_filter =["user_time","system_time","percent_cpu","mem_max"]
  end
  
  def run(cmd=nil)
    @cmd = Command.new(cmd) unless cmd.nil?
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

  def run_inst(filter)
    ### this function run the command instrumented with GNU time
    new_command = "/usr/bin/time -v #{@cmd.cmd}"
    @cmd = Command.new(new_command)
    @default_filter = filter unless filter.nil?
    self.run
    inst_output = []
    @stderr.select { |row|
      inst_output.push(row.scan(/: (.*)/)[0][0]) if in_filter?(row)
    }
    inst_output
  end

  private
  
  def in_filter?(row)
    @default_filter.each{ |key|
      return true if not row[Filter[key.to_sym]].nil?
    }
    return false
  end

end
