module AppleTvConverter
  class MediaConverterMacAdapter < MediaConverterAdapter
    def add_subtitles(media)
      puts "* Adding subtitles"

      # No need remove any subtitles, no video will have subtitles!
      # printf "  * Removing any previous subtitles"

      # command_line = %Q[./SublerCLI -remove -dest "#{media.converted_filename}"]

      # AppleTvConverter.logger.debug "Executing:"
      # AppleTvConverter.logger.debug command_line

      # output = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| stdout.read }

      # puts output.strip.empty? ? " [DONE]" : (output.strip == 'Error: (null)' ? " [NONE FOUND]" : " [ERROR]")

      if has_subtitles?(media)
        list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt')).map do |subtitle_filename|
          subtitle_filename =~ /(\w{3})\.srt$/
          language_code = $1 || 'eng'

          language = ::LanguageList::LanguageInfo.find_by_iso_639_3(language_code)
          language ||= ::LanguageList::LanguageInfo.find_by_iso_639_3('eng')


          command_line = "./SublerCLI "
          command_line << %Q[-source "#{subtitle_filename}" ]
          command_line << %Q[-language "#{language.name}" ]
          command_line << %Q[-dest "#{media.converted_filename}"]

          AppleTvConverter.logger.debug "Executing:"
          AppleTvConverter.logger.debug command_line

          printf "  * Adding #{language.name} subtitles"
          output = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| stdout.read }

          puts output.strip.empty? ? " [DONE]" : " [ERROR]"
        end
      else
        puts "  * No subtitles found"
      end
    end

    def tag(media)
      metadata = ''

      if media.is_tv_show_episode?
        metadata << %Q[{Name: #{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}}]
        metadata << %Q[{Genre: #{media.show}}]
        metadata << %Q[{TV Show: #{media.show}}]
        metadata << %Q[{TV Season: #{media.season}}]
        metadata << %Q[{TV Episode #: #{media.number}}]
      else
        imdb_movie = load_movie_from_imdb(media)

        if !imdb_movie
          metadata << %Q[{Name: #{media.show}}]
          metadata << %Q[{Genre: #{media.quality} Movies}]
        else
          metadata << %Q[{Name: #{imdb_movie.title}}]
          metadata << %Q[{Genre: #{imdb_movie.genres.first}}]
          metadata << %Q[{Description: #{imdb_movie.plot}}]
          metadata << %Q[{Release Date: #{imdb_movie.year}}]
          metadata << %Q[{Director: #{imdb_movie.director.first}}]
          metadata << %Q[{Codirector: #{imdb_movie.director[1]}}] if imdb_movie.director.length > 1

          if imdb_movie.poster
            open(imdb_movie.poster) do |f|
              File.open(media.artwork_filename,"wb") do |file|
                file.puts f.read
              end
            end

            metadata << %Q[{Artwork: #{media.artwork_filename}}]
          end
        end
      end

      metadata << %Q[{HD Video: true}] if media.hd?

      command_line = %Q[./SublerCLI -metadata "#{metadata}" -dest "#{media.converted_filename}"]

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      printf "* Tagging"

      output = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| stdout.read }

      puts output.strip.empty? ? " [DONE]" : " [ERROR]"

      return output.strip.empty?
    end

    def add_to_itunes(media)
      printf "  * Adding to iTunes"

      command_line = [
        "ln -s",
        "#{media.converted_filename}".gsub(/\s/, '\ ').gsub(/\[/, '\[').gsub(/\]/, '\]'),
        "#{File.expand_path(File.join('~', 'Music', 'iTunes', 'iTunes Media', 'Automatically Add to iTunes.localized'))}".gsub(/\s/, '\ ').gsub(/\[/, '\[').gsub(/\]/, '\]')
      ].join(' ')

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      `#{command_line}`

      puts ' [DONE]'
      return true
    end

    def list_files(ls)
      `ls -1 #{ls.gsub(/\s/, '\ ').gsub(/\[/, '\[').gsub(/\]/, '\]')} 2>/dev/null`.split("\n")
    end

    protected

      def get_transcode_options(media)
        options = {
          :video_codec => convert_video?(media) ? 'mpeg4' : 'copy',
          :audio_codec => convert_audio?(media) ? 'libfaac' : 'copy'
        }

        return options
      end
  end
end