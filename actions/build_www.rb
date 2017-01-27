module Fastlane
  module Actions
    class BuildWwwAction < Action
      def self.run(params)
        npm_build

        presets = params[:babel]
        presets = presets.split(',').map { |x| x.strip } if (presets.is_a? String)
        if !presets.empty? then
          babel(Pathname('www')/'build'/'main.js', presets, params[:compress])
          add_runtime(Pathname('node_modules')/'regenerator-runtime'/'runtime.js')
        end
      end

      def self.npm_build
        if !Pathname('www').exist? then
          sh("npm run build")
        end
      end

      def self.babel(src, presets, compress)
        UI.message "babel #{presets} with#{compress ? '' : 'out'} compress"
        tmp = src.dirname/'es5.js'

        sh("npm install babel-cli #{presets.map { |x| "babel-preset-#{x}" }.join(' ') }")
        sh("babel --presets=#{presets.join(',')} -o #{tmp} #{src}")

        if compress then
          sh('npm install uglify-js')
          sh("uglifyjs --compress --mangle --output #{src} -- #{tmp}")
        else
          tmp.rename src
        end

        jsmap = Pathname("#{src}.map")
        jsmap.delete if jsmap.exist?
      end

      def self.add_runtime(target_src)
        www = Pathname('www')
        target_dst = www/'babel-es5'/File.basename(target_src)
        FileUtils.mkdir_p target_dst.dirname
        FileUtils.copy target_src, target_dst
        target = target_dst.relative_path_from(www).to_s

        src = www/'index.html'
        lines = []
        open(src, 'r') do |f|
          f.each_line { |line|
            lines.push line
            /(^.+[\"\'])build\/polyfills\.js([\"\'].+$)/.match(line) do |m|
              lines.push "#{m[1]}#{target}#{m[2]}"
            end
          }
        end
        open(src, 'w') do |f|
          f.puts lines
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Build www , babel and uglifyjs"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :babel,
          env_name: 'BABEL_PRESETS',
          description: "Presets for using by babel",
          optional: true,
          default_value: ['es2015', 'stage-0'],
          is_string: false
          ),
          FastlaneCore::ConfigItem.new(key: :compress,
          description: "Compress after babel by uglifyjs",
          optional: true,
          default_value: true,
          is_string: false
          )
        ]
      end

      def self.authors
        ["Sawatani"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end