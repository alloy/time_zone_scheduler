# TimeZoneScheduler

[![Build Status](https://travis-ci.org/alloy/time_zone_scheduler.svg?branch=master)](https://travis-ci.org/alloy/time_zone_scheduler)

A Ruby library that assists in scheduling events whilst taking time zones into account. E.g. when to best deliver
notifications such as push notifications or emails.

It includes a ORM ‘view’ that is able to partition a collection by time zone and extends the partitions with the
TimeZoneScheduler API.

NOTE: _It is not yet battle-tested. This will all follow over the next few weeks._

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'time_zone_scheduler'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install time_zone_scheduler

## Usage

For full details, see [the documentation](http://www.rubydoc.info/gems/time_zone_scheduler).

Here’s an example that uses the ‘view’ ORM helper. This example uses Mongoid, but its usage is pretty much the same with
ActiveRecord.

```ruby
require 'time_zone_scheduler/view'

class User
  include Mongoid::Document

  field :time_zone, type: String

  extend TimeZoneScheduler::View
  view_field_as_time_zone :time_zone
end

User.create(time_zone: 'Europe/Amsterdam') # => #<User ID=1>
User.create(time_zone: 'Europe/Paris')     # => #<User ID=2>
User.create(time_zone: 'America/New_York') # => #<User ID=3>

time_zone_views = User.in_time_zones
p time_zone_views.map { |view| view.map(&:id) }    # => [[1], [2], [3]]
p time_zone_views.map { |view| view.map(&:class) } # => [Mongoid::Criteria, Mongoid::Criteria, Mongoid::Criteria]
p time_zone_views.map { |view| view.time_zone }    # => ['Europe/Amsterdam', 'Europe/Paris', 'America/New_York']
```

Now consider, for instance, that you want to schedule the delivery of Apple Push Notifications, but do want to respect
the user and so, regardless of the user’s time zone, always deliver on Friday, January the 15th of 2016, at 10AM:

```ruby
date_and_time = Time.parse('2016-01-15 10:00')

User.in_time_zones.each do |users|
  # Calculate the system time that corresponds to the date and time in the user’s time zone.
  run_at = users.schedule_on_date(date_and_time)
  # Perform the delivery of the push notifications on the calculated time.
  # (This example uses the DelayedJob API to delay delivery.)
  PushNotification.delay(run_at: run_at).deliver(users)
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alloy/time_zone_scheduler.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

