#! /usr/bin/env ruby
#
#   check-systemd-timers.rb
#
# DESCRIPTION:
# => Check the status of the systemd timers
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
# -s SERVICE - Timers to check delimited by commas
#
# LICENSE:
#   Release under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'

#
#  Check systemd services
#
class CheckSystemd < Sensu::Plugin::Check::CLI
  option :timers,
         short: '-t TIMERS',
         proc: proc { |a| a.split(',') }

  # Setup variables
  #
  def initialize
    super
    @timers = config[:timers]
    @services = @timers.inject([]) { |services, timer| services << timer.gsub(/.timer$/, '.service') }
    @crit_service = []
  end

  def all_service_names
    systemd_output = `systemctl --no-legend`
    systemd_output.split("\n").collect do |line|
      line.split(' ').first
    end
  end

  def unit_services
    systemd_output = `systemctl --failed --no-legend`
    service_array = []
    systemd_output.split("\n").each do |line|
      line_array = line.split(' ')
      next unless @services.any? { |service| line_array[0].include?(service) }
      service_hash = {}
      service_hash['name'] = line_array[0]
      service_hash['load'] = line_array[1]
      service_hash['active'] = line_array[2]
      service_hash['sub'] = line_array[3]
      service_hash['description'] = line_array[4]
      service_array.push(service_hash)
    end
    service_array
  end

  def check_systemd
    @timers.reject { |service| validate_presence_of(service) }.each do |gone|
      @crit_service << "#{gone} - Not Present"
    end

    unit_services.each do |service|
      if service['active'] != 'active'
        @crit_service << "#{service['name']} - #{service['active']}"
      elsif service['sub'] != 'running'
        @crit_service << "#{service['name']} - #{service['sub']}"
      end
    end
  end

  def service_summary
    @crit_service.join(', ')
  end

  def validate_presence_of(service)
    all_service_names.include?(service)
  end

  def run
    check_systemd
    critical service_summary unless @crit_service.empty?
    ok 'All services are running'
  end
end
