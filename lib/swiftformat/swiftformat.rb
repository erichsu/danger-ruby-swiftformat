require "logger"

module Danger
  class SwiftFormat
    def initialize(path = nil, project_root)
      @path = path || "swiftformat"
      @project_root = project_root
    end

    def installed?
      Cmd.run(%w(swift package plugin --list))[0].include?("‘swiftformat’")
    end

    def check_format(files, additional_args = "", swiftversion = "")
      cmd = @path.split + files
      cmd << additional_args.split unless additional_args.nil? || additional_args.empty?

      unless swiftversion.nil? || swiftversion.empty?
        cmd << "--swiftversion"
        cmd << swiftversion
      end

      cmd << %w(--lint --lenient)
      stdout, stderr, status = Cmd.run(cmd.flatten)

      output = stdout.empty? ? stderr : stdout
      raise "Error running SwiftFormat: Empty output." unless output

      output = output.strip.no_color

      if status && !status.success?
        raise "Error running SwiftFormat:\nError: #{output}"
      else
        raise "Error running SwiftFormat: Empty output." if output.empty?
      end

      process(output)
    end

    private

    def process(output)
      {
          errors: errors(output),
          stats: {
              run_time: run_time(output)
          }
      }
    end

    ERRORS_REGEX = /(.*:\d+:\d+): ((warning|error):.*)$/.freeze

    def errors(output)
      errors = []
      output.scan(ERRORS_REGEX) do |match|
        next if match.count < 2

        errors << {
            file: match[0].sub(@project_root, ""),
            rules: match[1].split(",").map(&:strip)
        }
      end
      errors
    end

    RUNTIME_REGEX = /.*SwiftFormat completed.*(.+\..+)s/.freeze

    def run_time(output)
      if RUNTIME_REGEX.match(output)
        RUNTIME_REGEX.match(output)[1]
      else
        logger = Logger.new($stderr)
        logger.error("Invalid run_time output: #{output}")
        "-1"
      end
    end
  end
end
