module Dister

  # Shared utility methods
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

    GIGA_SIZE = 1073741824.0
    MEGA_SIZE = 1048576.0
    KILO_SIZE = 1024.0

    # @param [Number] size Size to be converted
    # @param [Number] precision Number of decimals desired
    #
    # @return [String] Return the file size with a readable style.
    def readable_file_size(size, precision)
      case
        when size == 1 then "1 Byte"
        when size < KILO_SIZE then "%d Bytes" % size
        when size < MEGA_SIZE then "%.#{precision}f KB" % (size / KILO_SIZE)
        when size < GIGA_SIZE then "%.#{precision}f MB" % (size / MEGA_SIZE)
        else "%.#{precision}f GB" % (size / GIGA_SIZE)
      end
    end

  end
end
