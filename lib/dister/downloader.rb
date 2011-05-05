require 'ruby-debug'
module Dister
  class Downloader
    attr_reader :filename


    def initialize url, message
      @filename = File.basename(url)
      @message  = message
      
      # setup curl
      @curl = Curl::Easy.new
      @curl.url = url
      @curl.follow_location = true

      @curl.on_body { |data| self.on_body(data); data.size }
      @curl.on_complete { |data| self.on_complete }
      @curl.on_failure { |data| self.on_failure }
      @curl.on_progress do |dl_total, dl_now, ul_total, ul_now|
        self.on_progress(dl_now, dl_total, @curl.download_speed, @curl.total_time)
        true
      end
    end

    def start
      @file = File.open(@filename, "wb")
      @pbar = ProgressBar.new(@message, 100)
      @curl.perform
    end

    def on_body(data)
      @file.write(data)
    end

    def on_progress(downloaded_size, total_size, download_speed, downloading_time)
      if total_size > 0
        @pbar.set(downloaded_size / total_size * 100)
      end
    end

    def on_complete
      @pbar.finish
      @file.close
    end

    def on_failure
      begin
        unless code == 'Curl::Err::CurlOKNo error'
          @pbar.finish
          STDOUT.flush
          raise "Download failed with error code: #{code}"
        end
      ensure
        @file.close
      end
    end
  end
end
