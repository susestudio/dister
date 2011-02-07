module Dister
  class Downloader
    attr_reader :filename


    def initialize url, message, size
      @url = url
      @filename = File.basename(@url)
      @pbar = ProgressBar.new message, (size * 1024 * 1024)
    end

    def start
      curl = Curl::Easy.new(@url)
      file = File.open(@filename, "wb")
      curl.on_complete do |c|
        file.close
        @pbar.finish
      end
      curl.on_progress do |dl_total, dl_now, ul_total, ul_now|
        @pbar.set dl_now
      end
      curl.on_failure do |c, code|
        begin
          unless code == 'Curl::Err::CurlOKNo error'
            @pbar.finish
            STDOUT.flush
            raise "Download failed with error code: #{code}"
          end
        ensure
          file.close
        end
      end
      curl.on_body do |data|
        file.write(data)
      end
      curl.perform
    end
  end
end
