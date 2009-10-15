require 'rubygems'
require 'active_record'
require 'ttt/collector'

module TTT
  class Formatter
    attr :stream
    attr :cfg
    @@loaded_formatters = false
    @@formatters = {}
    @@runners = {}

    class_inheritable_accessor :media

    def initialize(stream, cfg)
      @stream=stream
      @cfg=cfg
    end

    def format(rows, *args)
      raise Exception, "Use a real formatter."
    end

    def reject_ignores(rows)
      if @cfg.key? "report_ignore"
        return rows.reject do |r|
          server_schema_table=[r.server, r.database_name, r.table_name].join(".")
          do_rej=false
          @cfg["report_ignore"].each do |reg|
            do_rej = !Regexp.new(reg).match(server_schema_table).nil?
            do_rej
            break if do_rej
          end
          do_rej
        end
      end
      return rows
    end

    def self.for(collector,output_media)
      @@formatters[collector] = {} if @@formatters[collector].nil?
      @@formatters[collector][output_media] = Proc.new
    end
    def self.runner_for(media)
      @@runners[media] = self
      self.media=media
    end
    def self.get_runner_for(media)
      self.load_all
      @@runners[media]
    end
    def self.get_formatter_for(collector, media)
      Collector.load_all
      @@formatters[collector][media]
    end

    def need_option(key)
      unless @cfg["formatter_options"].key? media.to_s and @cfg["formatter_options"][media.to_s].key? key
        raise NameError, "Missing formatter_options.#{media.to_s}.#{key} in config."
      end
      @cfg["formatter_options"][media.to_s][key]
    end

    def want_option(key, value=nil)
      unless @cfg["formatter_options"][media.to_s].key? key
        @cfg["formatter_options"][media.to_s][key]
      else
        value
      end
    end

    # Loads all formatters under: <gems path>/table-tracking-toolkit-<version>/lib/ttt/format/*
    # This must be called before formatters will function.
    def self.load_all
      unless @@loaded_formatters
        Dir.glob( File.dirname(__FILE__) + "/format/*" ).each do |col|
          Kernel.load col
        end
        @@loaded_formatters=true
      end
    end

  end
end