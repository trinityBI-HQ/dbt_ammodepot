# Data Transformation

> **Purpose**: JSON mapping, aggregation, filtering, and data reshaping patterns
> **MCP Validated**: 2026-02-19

## When to Use

- Converting API responses to database schema
- Aggregating multiple items into summary
- Filtering arrays based on conditions
- Reshaping nested JSON structures
- Normalizing inconsistent data formats

## Pattern 1: Field Mapping

```javascript
Edit Fields
  Fields to Set:
    - customer_email: {{ $json.email }}
    - full_name: {{ $json.firstName + ' ' + $json.lastName }}
    - created_at: {{ new Date($json.timestamp).toISOString() }}
  Fields to Remove: [email, firstName, lastName, timestamp]
```

## Pattern 2: Array Transformation

```javascript
// Split Out: Array to individual items
HTTP Request
  Response: [{"id": 1}, {"id": 2}]
→ Split Out: Field "json"
→ Result: 2 separate items
```

## Pattern 3: Aggregation

```javascript
Multiple items
  Item 1: {"price": 100, "quantity": 2}
  Item 2: {"price": 50, "quantity": 1}

→ Aggregate: Combine All
→ Code: Calculate totals
  const items = $input.all();
  const total = items.reduce((sum, item) =>
    sum + (item.json.price * item.json.quantity), 0
  );
  return { total_revenue: total, item_count: items.length };
```

## Pattern 4: Nested JSON Flattening

```javascript
Code Node
  Input: { "user": { "profile": { "email": "...", "name": "..." } } }

  const user = $json.user;
  return {
    email: user.profile.email,
    name: user.profile.name
  };
```

## Pattern 5: Filtering Data

```javascript
// Code node filtering
const items = $input.all();
const filtered = items.filter(item => {
  const user = item.json;
  const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
  return user.status === 'active' &&
         new Date(user.created_at) > thirtyDaysAgo;
});
return filtered.map(item => item.json);

// IF node for simple filtering
IF: {{ $json.status === 'active' }}
  → [true] → Process
  → [false] → Archive
```

## Pattern 6: Data Enrichment

```javascript
Webhook → Split Into Branches:
  Branch 1: → Fetch CRM data
  Branch 2: → Fetch Analytics data
→ Merge: Keep Matches
→ Code: Combine enriched data
```

## Pattern 7: Structure Transformation

```javascript
// API response to database schema
Code Node
  Input: API format
  const customer = $json.data.customer;
  return {
    customer_id: customer.id,
    email: customer.email,
    plan_name: customer.subscription.plan,
    renewal_date: new Date(customer.subscription.end * 1000).toISOString()
  };
  Output: Database format
```

## Best Practices

1. **Use Edit Fields for simple mappings** - Faster than Code
2. **Validate data types** - Check before transformation
3. **Handle null values** - Use `??` for defaults
4. **Test with edge cases** - Empty arrays, nulls
5. **Keep Code nodes focused** - One transformation per node
6. **Document complex logic** - Add Sticky Notes

## Type Conversions

```javascript
// Common conversions
const price = parseFloat($json.price) || 0;
const id = String($json.id);
const isoDate = new Date($json.timestamp).toISOString();
const parsed = JSON.parse($json.stringData);
```

## See Also

- [Expressions and Variables Concept](../concepts/expressions-variables.md)
- [Common Workflows Pattern](common-workflows.md)
