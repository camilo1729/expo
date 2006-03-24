require 'cmdctrl/commands/command'
require 'thread'
require 'stringio'

module CmdCtrl
  module Commands

    # Class used to buffer a Commands::Command
    class CommandBufferer

      # Bufferizes a Commands::Command
      def initialize(cmd)
        @stdout_string = StringIO::new
        @stdout_index = 0
        @stdout_mutex = Mutex::new
        @stderr_string = StringIO::new
        @stderr_index = 0
        @stderr_mutex = Mutex::new
        @on_output_block = nil
        @on_output_stdout_block = nil
        @on_output_stderr_block = nil
        @on_output_mutex = Mutex::new
        @on_exit_block = nil
        @on_exit_mutex = Mutex::new
        @waited = false
        @wait_mutex = Mutex::new
        
        raise "command must be a Commands::Command" unless cmd.kind_of?(Command)
        @command = cmd
      end

      # Runs the bufferized command
      def run
        @command.run
        # Get command IOs
        @stdin = @command.stdin
        @stdout = @command.stdout
        @stderr = @command.stderr
        # Create output reader
        @out_thread = Thread.new { 
          Thread.current.abort_on_exception = true
          begin
            while line = @stdout.gets
              @stdout_mutex.synchronize do
                @stdout_string.write(line)
              end
              @on_output_mutex.synchronize do
                if @on_output_stdout_block or @on_output_block
                  s = read_stdout
                  @on_output_stdout_block.call(s,self) if @on_output_stdout_block
                  @on_output_block.call(s,nil,self) if @on_output_block
                end
              end
            end
          rescue Errno::EIO
            nil
          ensure
            @stdout.close unless @stdout.closed? or @stdout == STDOUT
          end
        }
        # Create error reader
        @err_thread = Thread.new {
          Thread.current.abort_on_exception = true
          begin
            while line = @stderr.gets
              @stderr_mutex.synchronize do
                @stderr_string.write(line)
              end
              @on_output_mutex.synchronize do
                if @on_output_stderr_block or @on_output_block
                  s = read_stderr
                  @on_output_stderr_block.call(s,self) if @on_output_stderr_block
                  @on_output_block.call(nil,s,self) if @on_output_block
                end
              end
            end 
          rescue Errno::EIO
            nil
          ensure
            @stderr.close unless @stderr.closed? or @stderr == STDERR
          end
        }
        Thread.new {
          Thread.current.abort_on_exception = true
          status = wait
          @on_exit_block.call(status,self) if @on_exit_block
        }
        @command.pid
      end

      # Wait for the command to exit
      def wait
        @wait_mutex.synchronize do
          if not @waited
            @command.wait
            @out_thread.join
            @err_thread.join
            @stdin.close unless @stdin.closed? or @stdin == STDIN
            @waited = true
            @command.status
          else
            @command.status
          end
        end
      end

      # Allows to read the standard output from the beginning
      def rewind_stdout
        @stdout_index = 0
        self
      end

      # Allows to read the standard error from the beginning
      def rewind_stderr
        @stderr_index = 0
        self
      end

      # Writes the input on the command standard input
      def write_stdin(input)
        @stdin.syswrite(input)
        self
      end
      
      def puts_stdin(input)
        @stdin.puts(input)
        self
      end
      
      alias puts puts_stdin
      
      # Continues to read the standard output of the command and returns the string corresponding
      def read_stdout
        @stdout_mutex.synchronize do
          length = @stdout_string.length
          @stdout_string.seek(@stdout_index)
          sub_string = @stdout_string.read(length - @stdout_index)
          @stdout_index = @stdout_string.pos
          sub_string
        end
      end

      # Continues to read the standard error of the command and returns the string corresponding
      def read_stderr
        @stderr_mutex.synchronize do
          length = @stderr_string.length
          @stderr_string.seek(@stderr_index)
          sub_string = @stderr_string.read(length - @stderr_index)
          @stderr_index = @stderr_string.pos
          sub_string
        end
      end

      def gets_stdout
        @stdout_mutex.synchronize do
          @stdout_string.seek(@stdout_index)
          sub_string = @stdout_string.gets
          @stdout_index = @stdout_string.pos
          @stdout_string.seek(0,IO::SEEK_END)
          sub_string
        end
      end

      alias gets gets_stdout

      def gets_stderr
        @stderr_mutex.synchronize do
          @stderr_string.seek(@stderr_index)
          sub_string = @stderr_string.gets
          @stderr_index = @stderr_string.pos
          @stderr_string.seek(0,IO::SEEK_END)
          sub_string
        end
      end

      def on_output(&block)
        @on_output_mutex.synchronize do
          @on_output_block = block
        end
      end

      def on_output_stdout(&block)
        @on_output_mutex.synchronize do
          @on_output_stdout_block = block
        end
      end

      def on_output_stderr(&block)
        @on_output_mutex.synchronize do
          @on_output_stderr_block = block
        end
      end
      
      def on_exit(&block)
        @on_exit_mutex.synchronize do
          @on_exit_block = block
        end
      end

      # Returns the pid of the process being run
      def pid
        @command.pid
      end

      # Returns the command line being run
      def cmd
        @command.cmd
      end

      # Returns the status of the command when it exited, nil if it didn't
      def status
        @command.status
      end

      # Returns true if the command exited false unless
      def exited?
        return ! @command.status.nil?
      end
    end
  end
end
