# pipedrive-ruby

[![Gem Version](https://badge.fury.io/rb/pipedrive-ruby.png)](http://badge.fury.io/rb/pipedrive-ruby)
[![Code Climate](https://codeclimate.com/github/GeneralScripting/pipedrive-ruby.png)](https://codeclimate.com/github/GeneralScripting/pipedrive-ruby)
[![Build Status](https://travis-ci.org/GeneralScripting/pipedrive-ruby.png?branch=master)](https://travis-ci.org/GeneralScripting/pipedrive-ruby)
[![Coverage Status](https://coveralls.io/repos/GeneralScripting/pipedrive-ruby/badge.png?branch=master)](https://coveralls.io/r/GeneralScripting/pipedrive-ruby?branch=master)

## Installation

    gem install pipedrive-ruby

## Usage

    require 'pipedrive-ruby'
    Pipedrive.authenticate( YOUR_API_TOKEN )
    Pipedrive::Deal.find( DEAL_ID )

## API Calls
    Pipedrive::Deal.create( params )
    Pipedrive::Deal.find( <ID> )

    Pipedrive::Organization.create( params )
    Pipedrive::Organization.find( <ID> )

    Pipedrive::Person.create( params )
    Pipedrive::Person.find( <ID >)

    Pipedrive::Note.create( params )

You can check some of the calls at https://developers.pipedrive.com/v1

## API v2 Migration (Version 1.0.0+)

### Overview

Starting with version 1.0.0, this gem supports **dual API versions**:
- **API v2** for resources that have been migrated (Activity, Deal, Person, Organization, Product, Pipeline, Stage, SearchResult)
- **API v1** for resources that remain on v1 (Note, File, User, Filter, Goal, etc.)

This was implemented in response to [Pipedrive's deprecation announcement](https://developers.pipedrive.com/changelog/post/deprecation-of-selected-api-v1-endpoints) that specific v1 endpoints will be sunset on **December 31, 2025**.

### Resources Using API v2

The following resources now use the `/api/v2` endpoints:
- `Pipedrive::Activity`
- `Pipedrive::Deal`
- `Pipedrive::Person`
- `Pipedrive::Organization`
- `Pipedrive::Product`
- `Pipedrive::Pipeline`
- `Pipedrive::Stage`
- `Pipedrive::SearchResult`

### Resources Remaining on API v1

These resources continue to use `/v1` endpoints:
- `Pipedrive::Note`
- `Pipedrive::File`
- `Pipedrive::User`
- `Pipedrive::Filter`
- `Pipedrive::Goal`
- `Pipedrive::Currency`
- `Pipedrive::ActivityType`
- Field resources (DealField, PersonField, etc.)
- And others...

### V1 Compatibility Layer

The gem includes an abstraction layer that allows existing code to continue working without changes. The gem transparently handles V2 API differences:

#### Custom Fields (Automatic Flattening)

V2 API nests custom fields, but the gem flattens them automatically:

```ruby
# Your code stays the same:
deal.some_custom_field_hash  # Works - gem flattens from custom_fields
deal['some_custom_field_hash']  # Also works
```

#### Related Objects (Lazy Loading)

V2 API doesn't include related objects, but the gem lazy-loads them:

```ruby
deal = Pipedrive::Deal.find(123)
deal.organization  # Automatically fetches Organization.find(deal.org_id)
deal.person        # Automatically fetches Person.find(deal.person_id)
```

#### Option Labels (Automatic ID Resolution)

V2 API requires option IDs instead of labels. The gem converts automatically:

```ruby
# Your code can still send labels:
deal.update({ "yes_no_field_hash" => "Yes" })  # Gem converts "Yes" to option ID
```

#### Handled Automatically

These V2 changes are handled transparently by the gem:

- **Authentication**: Header-based for v2, query param for v1
- **HTTP Methods**: PATCH for v2 updates, PUT for v1
- **Custom Field Nesting**: Nested under `custom_fields` when writing to v2

### Timestamp Format Change

The only change you may need to handle is timestamps now use RFC 3339 format:

**v0.x:** `"2013-03-01 14:01:03"`
**v1.x:** `"2013-03-01T14:01:03Z"`

Ruby's `Time.parse` handles both formats automatically.

See [V2_MIGRATION_NOTES.md](V2_MIGRATION_NOTES.md) for complete technical details.

## Contributing to pipedrive-ruby
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## License

This gem is released under the [MIT License](http://www.opensource.org/licenses/MIT).
