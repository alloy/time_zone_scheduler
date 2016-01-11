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

  def schedule_in_timeframe(from, timeframe)
    time = time_in_local_timeframe(from, timeframe, true)
    time.in_time_zone(Time.zone)
  end

  def in_timeframe?(at, timeframe)
    time_in_local_timeframe(at, timeframe, false)
  end

  private

  def time_in_local_timeframe(reference, timeframe, return_time)
    time = reference.in_time_zone(@time_zone)
    date = time.strftime('%F')
    not_before = @time_zone.parse("#{date} #{timeframe.min}")
    if time < not_before
      result = :lt
    else
      not_after = @time_zone.parse("#{date} #{timeframe.max}")
      result = time > not_after ? :gt : :eq
    end
    if return_time
      case result
      when :lt then not_before
      when :gt then not_before.tomorrow
      when :eq then time
      end
    else
      result == :eq
    end
  end
end
