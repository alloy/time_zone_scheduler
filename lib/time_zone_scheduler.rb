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
    timeframe = TimeFrame.new(@time_zone, from, timeframe)
    if timeframe.reference_before_timeframe?
      timeframe.min
    elsif timeframe.reference_after_timeframe?
      timeframe.min.tomorrow
    else
      timeframe.local_time
    end.in_time_zone(Time.zone)
  end

  def in_timeframe?(at, timeframe)
    TimeFrame.new(@time_zone, at, timeframe).reference_in_timeframe?
  end

  private

  class TimeFrame
    def initialize(time_zone, reference_time, timeframe)
      @time_zone, @reference_time, @timeframe = time_zone, reference_time, timeframe
    end

    def local_time
      @local_time ||= @reference_time.in_time_zone(@time_zone)
    end

    def min
      @min ||= @time_zone.parse("#{date} #{@timeframe.min}")
    end

    def max
      @max ||= @time_zone.parse("#{date} #{@timeframe.max}")
    end

    def reference_before_timeframe?
      local_time < min
    end

    def reference_after_timeframe?
      local_time > max
    end

    def reference_in_timeframe?
      !reference_before_timeframe? && !reference_after_timeframe?
    end

    private

    def date
      @date ||= local_time.strftime('%F')
    end
  end
end
