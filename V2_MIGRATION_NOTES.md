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

### Sub-Resource Endpoints
- [ ] `/deals/{id}/products`
- [ ] `/deals/{id}/participants`
- [ ] `/deals/{id}/followers`
- [ ] `/deals/{id}/activities`
- [ ] `/deals/{id}/files`
- [ ] `/persons/{id}/deals`
- [ ] `/organizations/{id}/persons`
- [ ] `/organizations/{id}/deals`

### Breaking Changes Identified

1. **Base URL Change**: Must use `/api/v2` prefix (no alternatives)
2. **Authentication Change**: Token passed in `x-api-token` header instead of query parameter
   - **Code Impact**: Automatic - handled by Base class based on api_version
   - **User Impact**: None - transparent to gem users
3. **HTTP Method Change**: PUT → PATCH for all update operations
4. **Timestamp Format**: All timestamps now RFC 3339 with timezone
5. **Related Objects Removed**: `related_objects` key no longer in responses
   - **Code Impact**: `initialize_related_objects` method in base.rb (lines 57-70) becomes unused
   - **User Impact**: Users relying on related objects must make additional API calls
   - Example: Getting a deal's organization will require: `deal.organization_id` then `Organization.find(id)`
6. **Field Selectors Removed**: v1 syntax `/deals:(id,title,value)` no longer supported
   - **Code Impact**: This gem doesn't implement field selectors, so no code changes needed
   - **User Impact**: v2 always returns full objects (may increase response sizes)
   - Cannot optimize bandwidth by selecting specific fields
7. **Custom Fields Restructured**: **MAJOR BREAKING CHANGE**
   - **Code Impact**: Custom fields now nested under `custom_fields` key instead of root level
   - **User Impact**: Code accessing custom fields MUST be updated
   - **V1**: `deal.d4de1c1518b4531717c676029a45911c340390a6` and `deal.d4de1c1518b4531717c676029a45911c340390a6_currency`
   - **V2**: `deal.custom_fields['d4de1c1518b4531717c676029a45911c340390a6']['value']` and `deal.custom_fields['d4de1c1518b4531717c676029a45911c340390a6']['currency']`
   - Subfields no longer separate keys with suffixes - now nested within custom field object

### Test Cases to Update
- [ ] Update WebMock stubs to use v2 URLs
- [ ] Update test fixtures with v2 response formats
- [ ] Verify error handling still works

## Migration Strategy Decision

Since only SPECIFIC endpoints are deprecated (not the entire v1 platform), we have two options:

### Option A: Dual-Version Support (RECOMMENDED)
- Keep `base_uri` as `https://api.pipedrive.com/v1` by default
- Override `base_uri` only for resources that MUST migrate to v2
- Resources that can stay on v1 continue working unchanged
- **Pros**: No breaking changes for non-deprecated resources, gradual migration
- **Cons**: More complex implementation, maintaining two versions

### Option B: Full V2 Migration
- Change `base_uri` to `https://api.pipedrive.com/api/v2`
- All resources attempt to use v2
- Non-deprecated resources (Notes, Files, etc.) will break unless they exist in v2
- **Pros**: Simpler implementation
- **Cons**: May break resources that don't have v2 equivalents yet

**RECOMMENDATION**: Option A (Dual-Version Support) to avoid breaking non-deprecated resources

## Action Items
1. ✓ Manually review migration guide
2. ✓ Document all breaking changes found
3. ✓ Identify which resources MUST migrate vs can stay on v1
4. Implement dual-version support for smooth migration
