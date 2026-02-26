# Expressions and Variables

> **Purpose**: JavaScript expressions for dynamic data access and transformation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

All expressions in n8n use `{{ }}` syntax to dynamically reference data from previous nodes, access workflow metadata, and execute JavaScript. Expressions enable data-driven workflows where parameters adapt based on runtime data.

## The Pattern

```javascript
{{ $json.fieldName }}              // Current item field
{{ $input.item.json.fieldName }}   // Previous node output
{{ $('NodeName').item.json.field }}// Specific node by name
{{ $now }}                         // Current timestamp
{{ $workflow.id }}                 // Workflow metadata
```

## Data Access Patterns

```javascript
// Current item
{{ $json.email }}
{{ $json.user.address.city }}  // Nested access

// Previous node
{{ $input.item.json.userId }}

// Specific node
{{ $('HTTP Request').item.json.status }}

// All items from node
{{ $('HTTP Request').all() }}
```

## Built-in Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `$json` | `{{ $json.email }}` | Current item data |
| `$input` | `{{ $input.item.json.id }}` | Previous node output |
| `$workflow` | `{{ $workflow.id }}` | Workflow metadata |
| `$now` | `{{ $now }}` | Current timestamp |
| `$env` | `{{ $env.API_URL }}` | Environment variables (blocked in Code nodes v2.0+) |
| `$itemIndex` | `{{ $itemIndex }}` | Item position |

## JavaScript Expressions

```javascript
// String manipulation
{{ $json.email.toLowerCase() }}
{{ $json.name.split(' ')[0] }}
{{ `Hello ${$json.name}!` }}

// Conditional
{{ $json.status === 'active' ? 'enabled' : 'disabled' }}

// Array methods
{{ $json.items.map(i => i.price).reduce((a,b) => a+b, 0) }}

// Date
{{ new Date($json.timestamp).toISOString() }}

// Math
{{ Math.round($json.price * 1.1) }}
```

## Advanced Expressions (IIFE)

```javascript
// Multiple statements
{{
  (function() {
    const data = $json;
    let total = 0;
    for (let item of data.items) {
      total += item.price * item.quantity;
    }
    return total;
  })()
}}
```

## Common Mistakes

### Wrong
```javascript
Email: $json.email  // ❌ Missing brackets
{{ $json.HTTP Request.status }}  // ❌ Invalid syntax
```

### Correct
```javascript
Email: {{ $json.email }}  // ✅ Proper syntax
{{ $('HTTP Request').item.json.status }}  // ✅ Node reference
```

## Error Handling

```javascript
// Safe property access
{{ $json.user?.email ?? 'unknown@example.com' }}

// Try-catch
{{
  (function() {
    try {
      return JSON.parse($json.data);
    } catch (e) {
      return { error: 'Invalid JSON' };
    }
  })()
}}
```

## Best Practices

1. **Use expression editor** - Provides autocomplete
2. **Drag-and-drop data** - Generates expressions
3. **Handle nulls** - Use `??` and `?.` operators
4. **Keep simple** - Complex logic in Code node
5. **Name nodes clearly** - Makes references readable

## v2.0 Note

`$env` access works in expressions but is blocked in Code nodes by default (`N8N_BLOCK_ENV_ACCESS_IN_NODE=true`). Use credentials or External Secrets instead of environment variables in Code nodes.

## Related

- [Nodes and Workflows](nodes-workflows.md)
- [Data Transformation Pattern](../patterns/data-transformation.md)
