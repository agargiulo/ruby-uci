#!/usr/bin/env RBENV_VERSION=2.7.1 ruby
# frozen_string_literal: true

require_relative './uci_config'

# @param [String] filepath
# @return [UciConfig]
def load_uci_conf(filepath)
  lines = File.readlines(filepath)
  uc    = UciConfig.new lines
  uc.build_config!
end

def sort_uci_host_by_ip(uci)
  uci.conf['host'].sort! do |a, b|
    a_ip = a[:option]['ip'].split('.').last.to_i
    b_ip = b[:option]['ip'].split('.').last.to_i
    a_ip <=> b_ip
  end
end

def main
  filename = ARGV.first
  uc = load_uci_conf(filename)
  sort_uci_host_by_ip(uc)
  new_file = filename + '.new'
  File.open(new_file, 'w+') do |conf_file|
    conf_file.write(uc.dump_config!)
  end
end

main if $PROGRAM_NAME == __FILE__
