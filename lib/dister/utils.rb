module Dister
  module Utils
    module_function
    # Shows message and prints a dot per second until the block code 
    # terminates its execution.
    # Exceptions raised by the block are displayed and program exists with
    # error status 1.
    def execute_printing_progress message
      t = Thread.new do
        print "#{message}"
        while(true) do
          print "."
          STDOUT.flush
          sleep 1
        end
      end
      shell = Thor::Shell::Color.new
      begin
        ret = yield
        t.kill if t.alive?
        shell.say_status "[DONE]", "", :GREEN
        return ret
      rescue
        t.kill if t.alive?
        shell.say_status "[ERROR]", $!, :RED
        exit 1
      end
    end
  end
end
