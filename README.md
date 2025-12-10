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

### Breaking Changes in 1.0.0

#### 1. Custom Fields Structure

Custom fields are now nested under a `custom_fields` object instead of being at the root level:

**v0.x (API v1):**
```ruby
deal.some_custom_field_hash  # Direct access
deal.some_custom_field_hash_currency  # Subfield as separate attribute
```

**v1.x (API v2):**
```ruby
deal.custom_fields['some_custom_field_hash']['value']
deal.custom_fields['some_custom_field_hash']['currency']
```

#### 2. Timestamp Format

All timestamps are now in RFC 3339 format with timezone:

**v0.x:** `"2013-03-01 14:01:03"`
**v1.x:** `"2013-03-01T14:01:03Z"`

#### 3. Related Objects Removed

The `related_objects` field is no longer returned in v2 responses. You must make separate API calls to fetch related data:

**v0.x:**
```ruby
deal = Pipedrive::Deal.find(123)
org = deal.organization  # Automatically included
```

**v1.x:**
```ruby
deal = Pipedrive::Deal.find(123)
org = Pipedrive::Organization.find(deal.org_id)  # Separate call required
```

#### 4. Authentication Method Changes

API v2 uses header-based authentication instead of query parameters (handled automatically by the gem):

- **v1**: Token sent as query parameter `?api_token=xxx`
- **v2**: Token sent in header `x-api-token: xxx`

**No code changes required** - the gem automatically uses the correct authentication method based on the resource.

#### 5. HTTP Method Changes

Update operations now use `PATCH` instead of `PUT` for v2 resources (handled automatically by the gem).

### Migration Guide

For most users, upgrading to 1.0.0 should be seamless for basic CRUD operations. However:

1. **If you use custom fields**, update your code to access them via the `custom_fields` hash
2. **If you rely on related objects**, add explicit fetch calls for related resources
3. **If you parse timestamps**, ensure your code handles RFC 3339 format (Ruby's `Time.parse` handles this automatically)

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
