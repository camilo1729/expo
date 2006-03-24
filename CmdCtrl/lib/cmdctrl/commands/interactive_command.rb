require 'cmdctrl/commands/command'
require 'pty'
require 'termios'
require 'tmpdir'
require 'thread'

module CmdCtrl
  module Commands

    # Container class representing a command to run or running interactively in a pty
    class InteractiveCommand < Command

      # Creats a new command from the command line
      def initialize(cmd)
        super(cmd)
        @status_mutex = Mutex::new
        @status_condition = ConditionVariable::new
      end

      # Runs the command created
      def run
        @path = tmpfifo
        inited = 0
        inited_mutex = Mutex::new
        inited_condition = ConditionVariable::new
        Thread::new {
          begin
            # Spawn the command redirecting the error output to the temporary FIFO created
            PTY::spawn("#{cmd} 2> #{@path}") { |r, w, p|
              @stdout,@stdin,@pid = r,w,p
              @stderr = open(@path, 'r')
              # set flags for stdin (see termios(3))
              tio = Termios::getattr(@stdin)
              # set terminal in raw mode
              tio.c_iflag &= ~(Termios::IGNBRK|Termios::BRKINT|Termios::PARMRK|Termios::ISTRIP|Termios::INLCR|Termios::IGNCR|Termios::ICRNL|Termios::IXON)
              tio.c_oflag &= ~(Termios::OPOST)
              tio.c_lflag &= ~(Termios::ECHO|Termios::ECHONL|Termios::ICANON|Termios::ISIG|Termios::IEXTEN)
              tio.c_cflag &= ~(Termios::CSIZE|Termios::PARENB)
              tio.c_cflag |= Termios::CS8
              Termios::setattr(@stdin, Termios::TCSANOW, tio)
              inited_mutex.synchronize do
                inited = 1
                inited_condition.signal
              end
              wait
            }
          rescue PTY::ChildExited => e
            @status_mutex.synchronize do
              @status = e.status
            end
            @status_condition.broadcast
          ensure
            removefifo
          end
        }
        inited_mutex.synchronize do
          if inited == 0
            inited_condition.wait(inited_mutex)
          end
        end
        @pid
      end

      def wait
        @status_mutex.synchronize do
          if not @status
            @status_condition.wait(@status_mutex)
          end
        end
        [@pid,@status]
      end

      def wait_no_hang
        result = nil
        @status_mutex.lock
        if @status
          result = [@pid,@status]
        end
        @status_mutex.unlock
        result
      end

      def status
        result = nil
        @status_mutex.lock
        result = @status
        @status_mutex.unlock
        result
      end

      private

      # Closes the fifo used for stderr after command exited
      def removefifo
        File.unlink(@path) rescue STDERR.puts("rm <#{ @path }> failed")
        self
      end

      # Creates a temporary FIFO
      def tmpfifo
        path = nil
        42.times do |i|
          # FIXME utiliser tempfile
          tpath = File.join(Dir.tmpdir, "#{ $$ }.#{ rand }.#{ i }")
          system "mkfifo #{ tpath }"
          next unless $? == 0
          path = tpath
          break
        end
        raise "Could not generate tmpfifo" unless path
        path
      end
    end
  end
end
