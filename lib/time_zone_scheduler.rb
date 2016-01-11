require "time_zone_scheduler/version"

require "active_support/core_ext/time/zones"
require 'active_support/duration'

# A Ruby library that assists in scheduling events whilst taking time zones into account. E.g. when to best deliver
# notifications such as push notifications or emails.
#
# It relies on ActiveSupport’s time and time zone functionality and expects a current system time zone to be specified
# through `Time.zone`.
#
# ### Terminology
#
# Consider a server sending notifications to a user:
#
# - **system time**:           The local time of the server in the current time zone, as specified with `Time.zone`.
# - **reference time**:        The time that needs to be e.g. converted into the user’s destination time zone.
# - **destination time zone**: The time zone that the user resides in.
# - **destination time**:      The local time of the time zone that the user resides in.
#
class TimeZoneScheduler
  # @return [ActiveSupport::TimeZone]
  #         the destination time zone for the various calculations this class performs.
  #
  attr_reader :destination_time_zone

  # @param  [String, ActiveSupport::TimeZone] destination_time_zone
  #         the destination time zone that calculations will be performed in.
  #
  def initialize(destination_time_zone)
    @destination_time_zone = Time.find_zone!(destination_time_zone)
  end

  # This calculation takes the local date and time of day of the reference time and converts that to the exact same date
  # and time of day in the destination time zone and returns it in the system time. In other words, you’d use this to
  # calculate the system time at which a specific date and time of day occurs in the destination time zone.
  #
  # For instance, you could use this to schedule notifications that should be sent to users on specific days of the week
  # at times of the day that they are most likely to be good for the user. E.g. every Thursday at 10AM.
  #
  # @example Calculate the system time that corresponds to Sunday 2015-10-25 at 10AM in the Pacific/Niue time zone.
  #
  #   Time.zone      = "Pacific/Kiritimati" # Set the system time zone
  #   scheduler      = TimeZoneScheduler.new("Pacific/Niue")
  #   reference_time = Time.parse("2015-10-25 10:00 UTC")
  #   system_time    = scheduler.schedule_on_date(reference_time, false)
  #
  #   p reference_time # => Sun, 25 Oct 2015 10:00:00 UTC +00:00
  #   p system_time    # => Mon, 26 Oct 2015 11:00:00 LINT +14:00
  #
  #   p system_time.sunday? # => false
  #   p system_time.hour    # => 11
  #
  #   p local_time = system_time.in_time_zone("Pacific/Niue")
  #   p local_time.sunday? # => true
  #   p local_time.hour    # => 10
  #
  # @param  [Time] reference_time
  #         the reference date and time of day that’s to be scheduled in the destination time zone.
  #
  # @param  [Boolean] raise_if_time_has_passed
  #         whether or not to check if the time in the destination time zone has already passed.
  #
  # @raise  [ArgumentError]
  #         in case the check is enabled, this is raised if the time in the destination time zone has already passed.
  #
  # @return [Time]
  #         the system time that corresponds to the time scheduled in the destination time zone.
  #
  def schedule_on_date(reference_time, raise_if_time_has_passed = true)
    destination_time = @destination_time_zone.parse(reference_time.strftime('%F %T'))
    system_time = destination_time.in_time_zone(Time.zone)
    if raise_if_time_has_passed && system_time < Time.zone.now
      raise ArgumentError, "The specified time has already passed in the #{@destination_time_zone.name} timezone."
    end
    system_time
  end

  # This calculation schedules the time to be at the same time as the reference time (real time), except when that time,
  # in the destination time zone, falls _outside_ of the specified timeframe. In that case it delays the time until the
  # next minimum time of the timeframe is reached.
  #
  # For instance, you could use this to schedule notifications about an event starting in either real-time, if that’s a
  # good time for the user in their time zone, or otherwise delay it to the next good time.
  #
  # @example Return the real time, as the reference time falls in the specified timeframe in the Europe/Amsterdam time zone.
  #
  #   Time.zone      = "UTC" # Set the system time zone
  #   scheduler      = TimeZoneScheduler.new("Europe/Amsterdam")
  #   reference_time = Time.parse("2015-10-25 12:00 UTC")
  #   system_time    = scheduler.schedule_in_timeframe(reference_time, "10:00".."14:00")
  #   local_time     = system_time.in_time_zone("Europe/Amsterdam")
  #
  #   p reference_time # => Sun, 25 Oct 2015 12:00:00 UTC +00:00
  #   p system_time    # => Sun, 25 Oct 2015 12:00:00 UTC +00:00
  #   p local_time     # => Sun, 25 Oct 2015 13:00:00 CET +01:00
  #
  # @example Delay the reference time so that it’s not scheduled before 10AM in the Pacific/Kiritimati time zone.
  #
  #   Time.zone      = "UTC" # Set the system time zone
  #   scheduler      = TimeZoneScheduler.new("Pacific/Kiritimati")
  #   reference_time = Time.parse("2015-10-25 12:00 UTC")
  #   system_time    = scheduler.schedule_in_timeframe(reference_time, "10:00".."14:00")
  #   local_time     = system_time.in_time_zone("Pacific/Kiritimati")
  #
  #   p reference_time # => Sun, 25 Oct 2015 12:00:00 UTC +00:00
  #   p system_time    # => Sun, 25 Oct 2015 20:00:00 UTC +00:00
  #   p local_time     # => Mon, 26 Oct 2015 10:00:00 LINT +14:00
  #
  # @example Delay the reference time so that it’s not scheduled after 2PM in the Europe/Moscow time zone.
  #
  #   Time.zone      = "UTC" # Set the system time zone
  #   scheduler      = TimeZoneScheduler.new("Europe/Moscow")
  #   reference_time = Time.parse("2015-10-25 12:00 UTC")
  #   system_time    = scheduler.schedule_in_timeframe(reference_time, "10:00".."14:00")
  #   local_time     = system_time.in_time_zone("Europe/Moscow")
  #
  #   p reference_time # => Sun, 25 Oct 2015 12:00:00 UTC +00:00
  #   p system_time    # => Mon, 26 Oct 2015 07:00:00 UTC +00:00
  #   p local_time     # => Mon, 26 Oct 2015 10:00:00 MSK +03:00
  #
  # @param  [Time] reference_time
  #         the reference time that’s to be re-scheduled in the destination time zone if it falls outside the timeframe.
  #
  # @param  [Range<String..String>] timeframe
  #         a range of times (of the day) in which the scheduled time should fall.
  #
  # @return [Time]
  #         either the original reference time, if it falls in the timeframe, or the delayed time.
  #
  def schedule_in_timeframe(reference_time, timeframe)
    timeframe = TimeFrame.new(@destination_time_zone, reference_time, timeframe)
    if timeframe.reference_before_timeframe?
      timeframe.min
    elsif timeframe.reference_after_timeframe?
      timeframe.min.tomorrow
    else
      reference_time
    end.in_time_zone(Time.zone)
  end

  # This checks if the reference time falls in the given timeframe in the destination time zone.
  #
  # For instance, you could use this to disable playing a sound for notifications that **have** to be scheduled in real
  # time, but you don’t necessarily want to e.g. wake the user.
  #
  # @example Return that 1PM in the Europe/Amsterdam time zone falls in the timeframe.
  #
  #   Time.zone      = "UTC" # Set the system time zone
  #   scheduler      = TimeZoneScheduler.new("Europe/Amsterdam")
  #   reference_time = Time.parse("2015-10-25 12:00 UTC")
  #
  #   p scheduler.in_timeframe?(reference_time, "08:00".."14:00") # => true
  #
  # @example Return that 3PM in the Europe/Moscow time zone falls outside the timeframe.
  #
  #   Time.zone      = "UTC" # Set the system time zone
  #   scheduler      = TimeZoneScheduler.new("Europe/Moscow")
  #   reference_time = Time.parse("2015-10-25 12:00 UTC")
  #
  #   p scheduler.in_timeframe?(reference_time, "08:00".."14:00") # => true
  #
  # @param  [Time] reference_time
  #         the reference time that’s to be checked if it falls in the timeframe in the destination time zone.
  #
  # @param  [Range<String..String>] timeframe
  #         a range of times (of the day) in which the reference time should fall.
  #
  # @return [Boolean]
  #         whether or not the reference time falls in the specified timeframe in the destination time zone.
  #
  def in_timeframe?(reference_time, timeframe)
    TimeFrame.new(@destination_time_zone, reference_time, timeframe).reference_in_timeframe?
  end

  # @!visibility private
  #
  # Assists in calculations regarding timeframes. It caches the results so the caller doesn’t need to worry about cost.
  #
  class TimeFrame
    # @param  [ActiveSupport::TimeZone] destination_time_zone
    # @param  [Time] reference_time
    # @param  [Range<String..String>] timeframe
    #
    def initialize(destination_time_zone, reference_time, timeframe)
      @destination_time_zone, @reference_time, @timeframe = destination_time_zone, reference_time, timeframe
    end

    # @return [Time]
    #         the minimum time of the timeframe range in the destination time zone.
    #
    def min
      @min ||= @destination_time_zone.parse("#{local_date} #{@timeframe.min}")
    end

    # @return [Time]
    #         the maximum time of the timeframe range in the destination time zone.
    #
    def max
      @max ||= @destination_time_zone.parse("#{local_date} #{@timeframe.max}")
    end

    # @return [Boolean]
    #         whether the reference time falls before the timeframe.
    #
    def reference_before_timeframe?
      local_time < min
    end

    # @return [Boolean]
    #         whether the reference time falls after the timeframe.
    #
    def reference_after_timeframe?
      local_time > max
    end

    # @note   First checks if the reference time falls before the timeframe, because if that fails {#max} never needs to
    #         be performed for {TimeZoneScheduler#schedule_in_timeframe} to be able to perform its work.
    #
    # @return [Boolean]
    #         whether the reference time falls in the timeframe.
    #
    def reference_in_timeframe?
      !reference_before_timeframe? && !reference_after_timeframe?
    end

    private

    # @return [Time]
    #         the reference time in the destination timezone.
    #
    def local_time
      @local_time ||= @reference_time.in_time_zone(@destination_time_zone)
    end

    # @return [String]
    #         the date of the reference time in the destination timezone.
    #
    def local_date
      @date ||= local_time.strftime('%F')
    end
  end
end
