# API v2 Migration Notes

## Timeline
- **Deadline**: December 31, 2025
- **Started**: November 9, 2025
- **Important**: Only SPECIFIC v1 endpoints are deprecated, NOT the entire v1 platform!

## Documentation Links
- Migration Guide: https://pipedrive.readme.io/docs/pipedrive-api-v2-migration-guide
- V2 API Docs: https://pipedrive.readme.io/docs/pipedrive-api-v2
- Deprecation Announcement: https://developers.pipedrive.com/changelog/post/deprecation-of-selected-api-v1-endpoints

## Research Findings

### Base URL Changes
- [x] V1: `https://api.pipedrive.com/v1` (also supported `/api/v1`)
- [x] V2: `https://api.pipedrive.com/api/v2` (ONLY `/api/v2` prefix supported)
  - **Breaking**: Must use `/api/v2` prefix, no alternative prefixes

### HTTP Method Changes
- [x] Update operations: PUT → PATCH (confirmed - REST compliance)
  - **Breaking**: All PUT requests must change to PATCH in v2

### Authentication
- [x] **BREAKING CHANGE**: Authentication method changed!
  - **V1**: API token via query parameter `?api_token=xxx`
  - **V2**: API token via header `x-api-token: xxx`
  - The gem handles this automatically based on resource API version

### Response Structure
- [ ] Does v2 still use `data`, `additional_data` fields?
- [x] `related_objects` field: **REMOVED in v2**
  - **Breaking**: Related objects no longer returned in responses
  - Prevents eager fetching of unnecessary data
  - Must use subsequent API calls to fetch related objects when needed
- [x] Field selectors: **REMOVED in v2**
  - **Breaking**: v1 syntax like `/deals:(id,title,value,currency)` no longer supported
  - v2 always returns full objects with all fields
  - Cannot limit which fields are returned per object
- [x] Custom fields restructured: **MAJOR BREAKING CHANGE**
  - **V1**: Custom fields at root level with separate keys for subfields
    ```json
    {
      "d4de1c1518b4531717c676029a45911c340390a6": 2300,
      "d4de1c1518b4531717c676029a45911c340390a6_currency": "EUR"
    }
    ```
  - **V2**: Custom fields nested under `custom_fields` object
    ```json
    {
      "custom_fields": {
        "d4de1c1518b4531717c676029a45911c340390a6": {
          "value": 2300,
          "currency": "EUR"
        }
      }
    }
    ```
- [ ] Any new wrapper fields?
- [ ] Field name changes?

### Timestamp Format Changes
- [x] V1: Various timestamp formats
- [x] V2: RFC 3339 format (e.g., `2024-01-01T00:00:00Z` or `2024-01-01T00:00:00.000Z`)
  - **Breaking**: All timestamps now include timezone information
  - Ensures clarity regarding timezones

### Pagination
- [ ] Still uses `additional_data.pagination`?
- [ ] Still uses `more_items_in_collection` flag?
- [ ] Still uses `next_start` cursor?

### Affected Resources - Available in V2
- [x] Activities (`/activities`) - ✓ Available in v2
- [x] Deals (`/deals`) - ✓ Available in v2
- [x] Deal Followers - ✓ Available in v2
- [x] Deal Products - ✓ Available in v2
- [x] Persons (`/persons`) - ✓ Available in v2
- [x] Person Followers - ✓ Available in v2
- [x] Organizations (`/organizations`) - ✓ Available in v2
- [x] Organization Followers - ✓ Available in v2
- [x] Products (`/products`) - ✓ Available in v2
- [x] Product Followers - ✓ Available in v2
- [x] Product Variations - ✓ Available in v2
- [x] Pipelines (`/pipelines`) - ✓ Available in v2
- [x] Stages (`/stages`) - ✓ Available in v2
- [x] User Followers - ✓ Available in v2
- [x] Search endpoints - ✓ Available in v2

### Resources Remaining on V1 (NOT deprecated)
- [x] Notes (`/notes`) - ✓ Can stay on v1 - NOT deprecated
- [x] Files (`/files`) - ✓ Can stay on v1 - NOT deprecated
- [x] Filters (`/filters`) - ✓ Can stay on v1 - NOT deprecated
- [x] Goals (`/goals`) - ✓ Can stay on v1 - NOT deprecated
- [x] Users (`/users`) - ✓ Can stay on v1 - NOT deprecated
- [x] Activity Types (`/activityTypes`) - ✓ Can stay on v1 - NOT deprecated
- [x] Currencies (`/currencies`) - ✓ Can stay on v1 - NOT deprecated
- [x] Deal/Person/Organization/Product Fields - ✓ Can stay on v1 - NOT deprecated
- [x] Permission Sets (`/permissionSets`) - ✓ Can stay on v1 - NOT deprecated
- [x] Roles (`/roles`) - ✓ Can stay on v1 - NOT deprecated
- [x] User Connections (`/userConnections`) - ✓ Can stay on v1 - NOT deprecated
- [x] User Settings (`/userSettings`) - ✓ Can stay on v1 - NOT deprecated
- [x] Push Notifications (`/pushNotification`) - ✓ Can stay on v1 - NOT deprecated
- [x] Authorizations - ✓ Can stay on v1 - NOT deprecated

**IMPORTANT**: Only specific endpoints are deprecated. The v1 platform continues for non-migrated resources!

### Sub-Resource Endpoints (V2 uses query params instead)
- [x] `/deals/{id}/products` → `Deal#products` uses `/products?deal_id={id}`
- [x] `/deals/{id}/participants` → `Deal#participants` uses `/persons?deal_id={id}`
- [x] `/deals/{id}/activities` → `Deal#activities` uses `/activities?deal_id={id}`
- [x] `/organizations/{id}/persons` → `Organization#persons` uses `/persons?org_id={id}`
- [x] `/organizations/{id}/deals` → `Organization#deals` uses `/deals?org_id={id}`
- [ ] `/deals/{id}/followers` (v1 only)
- [ ] `/deals/{id}/files` (v1 only)
- [ ] `/persons/{id}/deals` (not yet updated)

### V2 API Changes (All Handled by Gem)

1. **Base URL Change**: Must use `/api/v2` prefix (no alternatives)
   - ✅ **Handled**: `base_uri_for_version` method in Base class
2. **Authentication Change**: Token passed in `x-api-token` header instead of query parameter
   - ✅ **Handled**: Automatic - handled by Base class based on api_version
3. **HTTP Method Change**: PUT → PATCH for all update operations
   - ✅ **Handled**: `prepare_update_request` method in Base class
4. **Timestamp Format**: All timestamps now RFC 3339 with timezone
   - ⚠️ **User-visible**: Only change users may need to handle (Ruby's `Time.parse` works with both)
5. **Related Objects Removed**: `related_objects` key no longer in responses
   - ✅ **Handled**: Lazy-loading methods (`deal.organization`, `deal.person`, etc.) fetch on access
   - `initialize_related_objects` still used for v1 resources
6. **Field Selectors Removed**: v1 syntax `/deals:(id,title,value)` no longer supported
   - ℹ️ **No impact**: This gem doesn't implement field selectors
7. **Custom Fields Restructured**:
   - ✅ **Handled on read**: `flatten_custom_fields` in `initialize()` flattens to V1-style top-level
   - ✅ **Handled on write**: `nest_custom_fields` in `prepare_update_request` nests for V2 API
   - Users can continue using `deal.custom_field_hash` or `deal['custom_field_hash']`
8. **Option IDs Required**: V2 requires option IDs instead of labels for enum fields
   - ✅ **Handled**: `resolve_option_labels` converts labels (e.g., "Yes") to IDs automatically

### Deal-Specific V2 Changes
Source: https://pipedrive.readme.io/docs/pipedrive-api-v2-migration-guide#post-apiv1deals-to-post-apiv2deals

1. **`user_id` → `owner_id`**: Field renamed for clarity and consistency
   - ✅ **Handled on write**: `transform_create_opts` converts `user_id` to `owner_id`
   - ✅ **Handled on read**: `initialize` aliases `owner_id` → `user_id` for backwards compatibility
2. **Related IDs no longer objects**: `creator_user_id`, `user_id`, `person_id`, `org_id` return IDs not objects
   - ✅ **Handled**: Lazy-loading methods (`deal.organization`, `deal.person`, `deal.user`) fetch on access

### Person-Specific V2 Changes

1. **`phone` → `phones`**: Field renamed and restructured to array of objects
   - ✅ **Handled on write**: `transform_create_opts` converts to `[{ "value": "...", "primary": true, "label": "work" }]`
   - ✅ **Handled on read**: `initialize` aliases `phones` → `phone` for backwards compatibility
2. **`email` → `emails`**: Field renamed and restructured to array of objects
   - ✅ **Handled on write**: `transform_create_opts` converts to `[{ "value": "...", "primary": true, "label": "work" }]`
   - ✅ **Handled on read**: `initialize` aliases `emails` → `email` for backwards compatibility

### Test Cases to Update
- [ ] Update WebMock stubs to use v2 URLs
- [ ] Update test fixtures with v2 response formats
- [ ] Verify error handling still works

## Migration Strategy Decision

Since only SPECIFIC endpoints are deprecated (not the entire v1 platform), we implemented:

### ✅ Option A: Dual-Version Support with Abstraction Layer

**Implemented approach:**
- Resources override `api_version` class method to declare 'v1' or 'v2'
- `Base` class dynamically sets `base_uri` based on resource's API version
- V1-compatible abstraction layer handles all V2 differences transparently
- Consuming apps (sales, invoice-tracker) require zero code changes

**Key abstraction features:**
- Custom fields flattened to top-level on read, nested on write
- Related objects lazy-loaded via accessor methods
- Option labels automatically resolved to IDs
- HTTP methods and authentication handled per API version

## Action Items
1. ✅ Manually review migration guide
2. ✅ Document all breaking changes found
3. ✅ Identify which resources MUST migrate vs can stay on v1
4. ✅ Implement dual-version support with abstraction layer
5. ✅ Test in sales app (console + manual testing)
6. ✅ Test in invoice-tracker app (console + manual testing)
7. [ ] Update test fixtures and WebMock stubs for v2 responses
8. [ ] Consider adding caching for lazy-loaded related objects (performance optimization)
