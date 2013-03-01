### This is an experimental wrapper for command execution


class Command

  attr_reader :stdout
  def initialize(cmd=nil,&block)
    @cmd = cmd
    @block = block
  end

  def run
    @stdout,@mystdout =IO::pipe
    @mystdin,@stdin = IO::pipe
    @stderr, @mystderr = IO::pipe
    # @stdout = IO::pipe
    # @stderr = IO::pipe
    fork do
      close_fds
      #puts "executing Fork"
      @mystdout.sync = true
      STDOUT.reopen(@mystdout)
      STDIN.reopen(@mystdin)
      STDERR.reopen(@mystderr)
      ## with some tests I discoverd that exec is much faster than system() twice
      exec(@cmd)
    end
    close_internal_fds
  end

  def close_fds
    @stdin.close unless @stdin.closed? or @stdin == STDIN
    @stdout.close unless @stdout.closed? or @stdout == STDOUT
    @stderr.close unless @stderr.closed? or @stderr == STDERR
  end

  private

      # Closes the open file descriptors
  def close_internal_fds        
    @mystdin.close unless @mystdin.closed? or @mystdin == STDIN
    @mystdout.close unless @mystdout.closed? or @mystdout == STDOUT
    @mystderr.close unless @mystderr.closed? or @mystderr == STDERR
    self
  end

end
