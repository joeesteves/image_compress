# frozen_string_literal: true

require 'webp-ffi'
require 'mini_magick'
require 'byebug'

class ImageCompress
  class << self
    def all(path)
      entries = trampoline { path_to_entries([path]) }
      total_entries = entries.length
      puts "will process #{total_entries}"
      puts 'Crtl - C to cancel'
      sleep(5)
      entries.each_with_index do |entry, idx|
        Process.fork do
          completed = (((idx + 1.0) / total_entries) * 100).round(2)
          puts "#{completed}%"
          compress(entry)
        end
      end
      Process.waitall
      puts "#{total_entries} images have been compressed"
      puts 'Done ✔'
    end

    private

    def trampoline
      f = yield
      loop do
        case f
        when Proc
          f = f[]
        else
          break f
        end
      end
    end

    def path_to_entries(path_list, file_list = [])
      puts path_list.length
      path_list = clean(path_list)
      return file_list if path_list.empty?

      head, *tail = path_list
      new_paths, new_entries =
        if File.directory?(head)
          [expand_folder(head), []]
        else
          [[], filter_images(head)]
        end
      -> { path_to_entries(new_paths | tail, new_entries | file_list) }
    end

    def compress(path, options = { quality: 50, method: 6 })
      webp_file_path = webp_file_path(path)
      WebP.encode(path, webp_file_path, options)
    rescue StandardError
      tmp_name = "#{Process.pid}_tmp.jpg"
      img = MiniMagick::Image.open(path)
      img.colorspace 'sRGB'
      img.format 'jpg'
      img.write tmp_name
      WebP.encode(tmp_name, webp_file_path, options)
      FileUtils.rm tmp_name
    end

    def filter_images(path)
      return [] if already_done?(path)

      path =~ /(jpeg|jpg)/ ? [path] : []
    end

    def already_done?(path)
      File.exist?(webp_path(path))
    end

    def webp_path(path)
      dirname = File.dirname(path)
      basename = File.basename(path)
      "#{dirname}/webp_#{basename}.webp"
    end

    def clean(paths)
      paths
        .reject { |path| path =~ /(\.|\.\.)$/ }
    end

    def expand_folder(path)
      Dir.entries(path)
         .map { |entry| File.join(path, entry) }
    end
  end
end
