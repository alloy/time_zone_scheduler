require "test_helper"

require "active_support/core_ext/numeric/time"

describe TimeZoneScheduler do
  before do
    # On the 25th of October 2015, at 02:00 UTC, DST ended in CET and clocks
    # were turned back 1 hour, which makes this an ideal scenario to test against.
    #
    #          Current time in Alofi is: 2015-10-24 01:00 (Pacific/Niue)
    #       Current time in New York is: 2015-10-24 08:00 (America/New_York)
    # Current time in Rio de Janeiro is: 2015-10-24 10:00 (Brazil/East)
    #      Current time in Amsterdam is: 2015-10-24 14:00 (Europe/Amsterdam)
    #         Current time in Moscow is: 2015-10-24 15:00 (Europe/Moscow)
    #   Current time in South Tarawa is: 2015-10-25 02:00 (Pacific/Kiritimati)
    #
    Time.zone = 'UTC'
    Timecop.freeze(ActiveSupport::TimeZone['UTC'].parse('2015-10-24 12:00'))
  end

  it "initializes with a destination time zone name" do
    scheduler = TimeZoneScheduler.new("Europe/Amsterdam")
    scheduler.destination_time_zone.must_equal ActiveSupport::TimeZone["Europe/Amsterdam"]
  end

  describe "#schedule_on_date" do
    {
      'Pacific/Kiritimati' => 8,
        'Europe/Amsterdam' => 21, # +1 for DST change
           'Europe/Moscow' => 19,
             'Brazil/East' => 24,
        'America/New_York' => 26,
            'Pacific/Niue' => 33,
    }.each do |time_zone, hours_from_now|
      it "schedules the date+time in `#{time_zone}' to be #{hours_from_now} hours from now" do
        reference_time = ActiveSupport::TimeZone['UTC'].parse('2015-10-25 10:00')

        scheduler = TimeZoneScheduler.new(time_zone)
        system_time = scheduler.schedule_on_date(reference_time)

        system_time.must_equal hours_from_now.hours.from_now

        destination_time = system_time.in_time_zone(time_zone)
        destination_time.sunday?.must_equal true
        destination_time.hour.must_equal 10
      end
    end

    it 'raises an error if the time has already passed in any of the timezones' do
      # This has been 2 hours ago in South Tarawa
      reference_time = ActiveSupport::TimeZone['UTC'].parse('2015-10-25 00:00')
      lambda do
        TimeZoneScheduler.new('Pacific/Kiritimati').schedule_on_date(reference_time)
      end.must_raise(ArgumentError)
    end
  end

  describe "#schedule_in_timeframe" do
    before do
      # Reference time in UTC: 2015-10-25 12:00
      @reference_time = ActiveSupport::TimeZone['Brazil/East'].parse('2015-10-25 10:00')
      @timeframe = '08:00'..'14:00'
      @real_time = 24.hours.from_now
    end

    it 'delivers in real-time where local time falls within the allowed timeframe' do
      # This is in the reference timezone, so no changes required.
      TimeZoneScheduler.new('Brazil/East').schedule_in_timeframe(@reference_time, @timeframe).must_equal(@real_time)
      # This is 2015-10-25 08:00 (America/New_York).
      TimeZoneScheduler.new('America/New_York').schedule_in_timeframe(@reference_time, @timeframe).must_equal(@real_time)
      # This is 2015-10-25 15:00 (Europe/Amsterdam) with DST, but as during
      # this night DST ended, it is actually 2015-10-25 14:00.
      TimeZoneScheduler.new('Europe/Amsterdam').schedule_in_timeframe(@reference_time, @timeframe).must_equal(@real_time)
    end

    it 'delays those that fall before the allowed timeframe till start same day' do
      # This is 2015-10-26 02:00 Pacific/Kiritimati.
      TimeZoneScheduler.new('Pacific/Kiritimati').schedule_in_timeframe(@reference_time, @timeframe).must_equal(@real_time + 6.hours)
      # This is 2015-10-25 01:00 Pacific/Niue.
      TimeZoneScheduler.new('Pacific/Niue').schedule_in_timeframe(@reference_time, @timeframe).must_equal(@real_time + 7.hours)
    end

    it 'delays those that fall after the allowed timeframe till start next day' do
      # This is 2015-10-25 15:00 Europe/Moscow.
      TimeZoneScheduler.new('Europe/Moscow').schedule_in_timeframe(@reference_time, @timeframe).must_equal(@real_time + 17.hours)
    end
  end

  describe "#in_timeframe?" do
    it "returns whether or not the local time falls within the allowed timeframe" do
      # Reference time in UTC: 2015-10-25 12:00
      reference_time = ActiveSupport::TimeZone["Brazil/East"].parse('2015-10-25 10:00')

      %w{ America/New_York Brazil/East Europe/Amsterdam }.each do |time_zone|
        TimeZoneScheduler.new(time_zone).in_timeframe?(reference_time, '08:00'..'14:00').must_equal true
      end

      %w{ Europe/Moscow Pacific/Kiritimati Pacific/Niue }.each do |time_zone|
        TimeZoneScheduler.new(time_zone).in_timeframe?(reference_time, '08:00'..'14:00').must_equal false
      end
    end
  end
end
