# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `pipedrive-ruby`, a Ruby gem that provides an API wrapper for the Pipedrive CRM API. The gem uses HTTParty for HTTP requests and provides an object-oriented interface for interacting with Pipedrive resources.

## Development Commands

### Setup
```bash
bundle install
```

### Testing
```bash
# Run all tests
rake test

# Run a specific test file
ruby -I lib:test test/test_pipedrive_deal.rb
```

### Build and Release
```bash
# Build the gem
rake build

# Generate documentation
rake rdoc
```

## Architecture

### Base Class Pattern
All Pipedrive resource classes inherit from `Pipedrive::Base` (lib/pipedrive/base.rb), which provides:
- HTTParty integration with the Pipedrive API (base URI: `https://api.pipedrive.com/v1`)
- Common CRUD operations: `create`, `find`, `all`, `update`, `destroy`
- Search functionality: `search`, `find_by_name`
- Authentication via API token using `default_params`
- Automatic resource path generation based on class name (e.g., `Deal` → `/deals`, `Activity` → `/activities`)

### Multi-Account Support
The gem supports accessing multiple Pipedrive accounts in the same session:
```ruby
# Global authentication (single account)
Pipedrive.authenticate(API_TOKEN)

# Per-request authentication (multiple accounts)
Pipedrive::Deal.auth(API_TOKEN).find(DEAL_ID)
```

### Resource Structure
Each resource (Deal, Person, Organization, etc.) is defined in `lib/pipedrive/*.rb`. Resources typically:
- Inherit from `Pipedrive::Base`
- Define instance methods for sub-resource access (e.g., `deal.products`, `person.deals`)
- Define instance methods for related actions (e.g., `add_follower`, `add_note`)
- May override class methods for custom search behavior (e.g., `Person.find_by_name`)

### Key Resource Relationships
- `Deal` has: products, participants (persons), followers (users), activities, files, notes
- `Person` has: deals, followers
- `Organization` has: persons, deals, followers
- Related objects are automatically initialized from API responses via `initialize_related_objects`

### Testing Approach
Tests use:
- `test-unit` framework with `shoulda` for context/setup blocks
- `webmock` for stubbing HTTP requests
- Test fixtures in `test/data/*.json` for API responses
- Helper methods in `test/helper.rb` for common stub setup

### Resource Path Naming Convention
The `resource_path` method in `Base` automatically converts class names to API endpoints:
- Capitalizes first letter → lowercase (e.g., `Deal` → `deal`)
- Pluralizes by adding 's' or converting 'y' to 'ies' (e.g., `Activity` → `activities`)
- Resource classes with hyphens in filenames use CamelCase (e.g., `ActivityType`, `DealField`)

## Key Implementation Details

### Error Handling
- Failed API responses trigger `bad_response` which raises `HTTParty::ResponseError`
- Success is checked via `res.success?` or `res.ok?` before processing response data

### Pagination
The `all` method supports pagination through the `get_absolutely_all` parameter, which recursively fetches all pages using the `next_start` cursor from `additional_data.pagination`.

### Data Initialization
API responses are wrapped in OpenStruct objects, merging:
- Main response data from `data` field
- Additional metadata from `additional_data` field
- Related objects from `related_objects` field (converted to their respective classes)
