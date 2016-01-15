require 'test_helper'
require 'time_zone_scheduler/view'

# Represents e.g. ActiveRecord::Relation or Mongoid::Criteria
Query = Struct.new(:value)

describe TimeZoneScheduler::View do
  it 'defines a Mongoid view getter' do
    model = Object.new
    time_zones = %w( Europe/Amsterdam America/New_York )

    scoped = Object.new
    model.define_singleton_method :scoped do
      scoped
    end
    scoped.define_singleton_method :distinct do |field|
      time_zones if field == :timezone
    end
    time_zones.each do |time_zone|
      scoped.define_singleton_method :where do |params|
        Query.new(params.values.first) if params.keys == [:timezone]
      end
    end

    model.extend TimeZoneScheduler::View
    model.view_field_as_time_zone :timezone

    model.in_time_zones.zip(time_zones).each do |view, expected_time_zone|
      view.class.must_equal Query
      view.value.must_equal expected_time_zone
      view.time_zone_scheduler.destination_time_zone.name.must_equal expected_time_zone
    end
  end

  it 'defines a ActiveRecord view getter' do
    model = Object.new
    time_zones = %w( Europe/Amsterdam America/New_York )

    scoped = Object.new
    model.define_singleton_method :scope do
      scoped
    end
    selected = Object.new
    scoped.define_singleton_method :select do |field|
      selected if field == :timezone
    end
    selected.define_singleton_method :distinct do
      time_zones
    end
    time_zones.each do |time_zone|
      scoped.define_singleton_method :where do |params|
        Query.new(params.values.first) if params.keys == [:timezone]
      end
    end

    model.extend TimeZoneScheduler::View
    model.view_field_as_time_zone :timezone

    model.in_time_zones.zip(time_zones).each do |view, expected_time_zone|
      view.class.must_equal Query
      view.value.must_equal expected_time_zone
      view.time_zone_scheduler.destination_time_zone.name.must_equal expected_time_zone
    end
  end
end

describe TimeZoneScheduler::View::Mixin do
  it 'forwards the various scheduling methods to the scheduler' do
    scheduler = Minitest::Mock.new

    view = Object.new
    view.extend TimeZoneScheduler::View::Mixin
    view.time_zone_scheduler = scheduler

    scheduler.expect(:schedule_on_date, nil, [:time])
    view.schedule_on_date(:time)

    scheduler.expect(:schedule_in_timeframe, nil, [:time, :timeframe])
    view.schedule_in_timeframe(:time, :timeframe)

    scheduler.expect(:in_timeframe?, nil, [:time, :timeframe])
    view.in_timeframe?(:time, :timeframe)

    scheduler.verify
  end
end

