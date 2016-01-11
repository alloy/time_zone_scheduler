require "time_zone_scheduler/version"

require "active_support/core_ext/time/zones"
require 'active_support/duration'

class TimeZoneScheduler
  attr_reader :time_zone

  def initialize(time_zone)
    @time_zone = Time.find_zone!(time_zone)
  end

  def schedule_on_date(at)
    reference = at.strftime('%F %T')
    time = @time_zone.parse(reference)
    system_time = time.in_time_zone(Time.zone)
    if system_time < Time.zone.now
      raise ArgumentError, "The specified time has already passed in the #{@time_zone.name} timezone."
    end
    system_time
  end
end
