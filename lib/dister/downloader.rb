require 'curb'
require 'progressbar'

module Dister
  class Downloader
    def initialize url, message, size
      puts size
      @url = url
      @pbar = ProgressBar.new message, (size * 1024 * 1024)
    end

    def start
      curl = Curl::Easy.new(@url)

      curl.on_complete do |c|
        @pbar.finish
      end 
      curl.on_progress do |dl_total, dl_now, ul_total, ul_now|
        @pbar.set dl_now
      end
      curl.on_failure do |c, code|
        @pbar.finish
        STDOUT.flush
        raise "Download failed with error code: #{code}"
      end
      curl.perform
    end
  end
end
