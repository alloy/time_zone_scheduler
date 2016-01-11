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

  it "initializes with a time zone name" do
    scheduler = TimeZoneScheduler.new("Europe/Amsterdam")
    scheduler.time_zone.must_equal ActiveSupport::TimeZone["Europe/Amsterdam"]
  end

  describe "#schedule_on_date" do
    before do
      @at = ActiveSupport::TimeZone['UTC'].parse('2015-10-25 10:00')
    end

    {
      'Pacific/Kiritimati' => 8,
        'Europe/Amsterdam' => 21, # +1 for DST change
           'Europe/Moscow' => 19,
             'Brazil/East' => 24,
        'America/New_York' => 26,
            'Pacific/Niue' => 33,
    }.each do |time_zone, hours_from_now|
      it "schedules the date+time in `#{time_zone}' to be #{hours_from_now} hours from now" do
        scheduler = TimeZoneScheduler.new(time_zone)
        scheduled_time = scheduler.schedule_on_date(@at)

        scheduled_time.must_equal hours_from_now.hours.from_now

        local_time = scheduled_time.in_time_zone(time_zone)
        local_time.sunday?.must_equal true
        local_time.hour.must_equal 10
        local_time.min.must_equal 0
      end
    end

    it 'raises an error if the time has already passed in any of the timezones' do
      # This has been 2 hours ago in South Tarawa
      at = ActiveSupport::TimeZone['UTC'].parse('2015-10-25 00:00')
      lambda do
        TimeZoneScheduler.new('Pacific/Kiritimati').schedule_on_date(at)
      end.must_raise(ArgumentError)
    end
  end
end
