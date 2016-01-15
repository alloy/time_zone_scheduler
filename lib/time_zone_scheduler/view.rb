require 'time_zone_scheduler'
require 'forwardable'

class TimeZoneScheduler
  module View
    # Defines a singleton method called `in_time_zones` which returns a list of
    # views on the model partitioned by the time zones available in the specified
    # time zone model field.
    #
    # It is able to extend ActiveRecord and Mongoid models.
    #
    # @see View#in_time_zones
    #
    # @param  [Symbol] time_zone_field
    #         the model field that holds the time zone names.
    #
    # @param  [String] default_time_zone
    #         the time zone to use if the value of the field can be `nil`.
    #
    # @return [void]
    #
    def view_field_as_time_zone(time_zone_field, default_time_zone = nil)
      time_zone_scopes = lambda do |scope, time_zones|
        time_zones.map do |time_zone|
          scope.where(time_zone_field => time_zone).tap do |scope|
            scope.extend Mixin
            scope.time_zone_scheduler = TimeZoneScheduler.new(time_zone || default_time_zone)
          end
        end
      end

      if respond_to?(:scoped)
        # Mongoid
        define_singleton_method :in_time_zones do
          time_zone_scopes.call(scoped, scoped.distinct(time_zone_field))
        end
      elsif respond_to?(:scope)
        # ActiveRecord (has dropped `scoped` since v4.0.2)
        define_singleton_method :in_time_zones do
          time_zone_scopes.call(scope, scope.select(time_zone_field).distinct)
        end
      else
        raise 'Unknown ORM.'
      end
    end

    # Defines a singleton method called `in_time_zones` which returns a list of
    # views on the model partitioned by the time zones available in the specified
    # time zone model field.
    #
    # Returns views that are regular `Mongoid::Criteria` or `ActiveRecord::Relation` instances created from the current
    # scope (and narrowed down by time zone), but are extended with the `TimeZoneScheduler` API.
    #
    # @see https://github.com/alloy/time_zone_scheduler
    # @see http://www.rubydoc.info/gems/time_zone_scheduler/TimeZoneScheduler
    #
    # @example
    #
    #   class User
    #     field :time_zone, type: String
    #
    #     extend TimeZoneScheduler::View
    #     view_field_as_time_zone :time_zone
    #   end
    #
    #   User.create(time_zone: 'Europe/Amsterdam')
    #   time_zone_view = User.in_time_zones.first
    #
    #   p time_zone_view # => #<User where: { time_zone: 'Europe/Amsterdam' }>
    #   p time_zone_view.time_zone # => 'Europe/Amsterdam'
    #   p time_zone_view.time_zone_scheduler # => #<TimeZoneScheduler>
    #
    #   # See TimeZoneScheduler for documentation on these available methods.
    #   time_zone_view.schedule_on_date(time)
    #   time_zone_view.schedule_in_timeframe(time, timeframe)
    #   time_zone_view.in_timeframe?(time, timeframe)
    #
    # @return [Array<Mongoid::Criteria, ActiveRecord::Relation, TimeZoneScheduler::View::Mixin>]
    #         a list of criteria partitioned by time zone and extended with the {Mixin} module.
    #
    def in_time_zones
      raise 'Need to call view_field_as_time_zone first.'
    end

    module Mixin
      extend Forwardable

      attr_accessor :time_zone_scheduler
      def_delegator :time_zone_scheduler, :destination_time_zone, :time_zone
      def_delegator :time_zone_scheduler, :schedule_on_date
      def_delegator :time_zone_scheduler, :schedule_in_timeframe
      def_delegator :time_zone_scheduler, :in_timeframe?
    end
  end
end
