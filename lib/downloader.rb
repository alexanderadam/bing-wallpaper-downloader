# frozen_string_literal: true

require 'fileutils'
require 'uri'
require 'net/http'
require 'json'
require 'open-uri'

module BingWallpaperDownloader
  class DownloaderError < StandardError; end

  # Bing JSON API: http://stackoverflow.com/questions/10639914/is-there-a-way-to-get-bings-photo-of-the-day
  class Downloader
    attr_reader :destination, :locale, :resolution, :total

    def initialize(destination, locale, resolution, total = 1)
      @destination = destination
      @locale      = locale
      @resolution  = resolution
      @total       = total
    end

    def download
      download_images(parse_image_json)
    end

    private

    def bing_json_url
      URI::HTTP.build(
        host: 'www.bing.com',
        path: '/HPImageArchive.aspx',
        query: URI.encode_www_form({
                                     format: 'js',
                                     idx: 0,
                                     n: @total,
                                     mkt: @locale
                                   })
      )
    end

    def parse_image_json
      json        = JSON.parse(Net::HTTP.get(bing_json_url))
      images_json = json['images']

      raise 'Could not get image JSON from Bing' unless images_json.any?

      images_json.collect do |image|
        date = image['startdate']
        date = "#{date[0..3]}-#{date[4..5]}-#{date[6..7]}"

        { url: URI.parse('http://www.bing.com' + image['url']), date: date }
      end
    end

    def download_images(images)
      images.collect do |image|
        begin
          url = image[:url].to_s.sub('1920x1080', @resolution)
          download = URI.open(url)
        rescue OpenURI::HTTPError
          raise DownloaderError, "No image available in #{@resolution} resolution"
        end

        if download.meta['content-type'] != 'image/jpeg' || download.meta['content-length'].to_i.zero?
          raise DownloaderError, 'Unable to download latest Bing image'
        end

        target = File.join(destination, image[:date] + '.jpg')
        bytes  = IO.copy_stream(download, target)
        raise DownloaderError, 'Unable to copy latest Bing image' if bytes != download.meta['content-length'].to_i

        target
      end
    end
  end
end
