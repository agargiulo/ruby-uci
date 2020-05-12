# frozen_string_literal: true

require 'json'
require 'stringio'

# General config wrapper for Uci things
class UciConfig
  attr_reader :conf

  # @param [Array] raw_lines
  def initialize(raw_lines)
    @conf  = {}
    @lines = raw_lines
    @conf_block = nil
  end

  def build_config!
    @lines.each do
      if _1.chomp.empty?
        @conf_block = _commit_block!
        next
      end

      _parse_line! _1
    end
    self
  end

  def dump_config!
    (conf_buf = StringIO.new).write("\n")
    @conf.each do |sect, sub_sects|
      meth = :"_dump_sub_#{{ Array => :list, Hash => :dict }[sub_sects.class]}!"
      if respond_to? meth, true
        send meth, conf_buf, sect, sub_sects
      else
        warn "Invalid sub_sect: #{JSON.pretty_generate({ sect: sect, sub_sects: sub_sects })}"
      end
    end
    conf_buf.string
  end

  private

  CONFIG_REGEX = /^config (?<sect>\w+) ?('(?<name>\w+)')?$/.freeze
  OPTION_REGEX = /^\t(?<ltype>option|list) (?<opt>\w+) '(?<opt_arg>.*)'$/.freeze
  BLOCK_TYPES  = %i[option list dict].freeze

  def _dump_sub_dict!(conf_buf, sect, sub_sects)
    sub_sects.each do |sect_name, sub_sect|
      conf_buf.write("config #{sect} '#{sect_name}'\n")
      _dump_opts! conf_buf, sub_sect
    end
  end

  def _dump_sub_list!(conf_buf, sect, sub_sects)
    sub_sects.each do |sub_sect|
      conf_buf.write("config #{sect}\n")
      _dump_opts! conf_buf, sub_sect
    end
  end

  def _dump_opts!(conf_buf, sub_sect)
    sub_sect.each do |opt_key, opt_vals|
      opt_vals.each do |opt, opt_arg|
        conf_buf.write("\t#{opt_key} #{opt} '#{opt_arg}'\n")
      end
    end
    conf_buf.write("\n")
  end

  def _commit_block!
    return if @conf_block.nil?

    meth = :"_commit_#{@conf_block.block_type}!"
    if respond_to? meth, true
      send meth
    else
      warn "invalid config block: \n#{JSON.pretty_generate(@conf_block)}"
    end
  end

  def _commit_dict!
    @conf[@conf_block.sect] ||= {}
    @conf[@conf_block.sect][@conf_block.block_name] = @conf_block.config
    nil
  end

  def _commit_list!
    @conf[@conf_block.sect] ||= []
    @conf[@conf_block.sect].append(@conf_block.config)
    nil
  end

  def _parse_line!(line)
    config_line = line.scan(CONFIG_REGEX).flatten.compact
    type = BLOCK_TYPES[config_line.length]
    if @conf_block.nil? && type != :option
      @conf_block = UciConfigBlock.new(type, config_line)
    elsif @conf_block
      _parse_option_line line
    else
      warn "Something strange on line: #{line}"
    end
  end

  def _parse_option_line(line)
    opts = line.scan(OPTION_REGEX).flatten
    conf = {
      opts.first => {
        opts[1] => opts[2]
      }
    }
    @conf_block.config.merge!(conf) { |_key, old_val, new_val| old_val.merge(new_val) }
  end
end

# A single config block
class UciConfigBlock
  attr_reader :block_type, :sect, :block_name, :config

  def initialize(block_type, data)
    @block_type = block_type
    @sect = data.first
    @block_name = data.last if data.length == 2
    @config = {}
  end
end
