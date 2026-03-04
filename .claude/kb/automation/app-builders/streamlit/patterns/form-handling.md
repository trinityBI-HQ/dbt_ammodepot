# Form Handling Pattern

> **Purpose**: Forms, validation, dialogs, and structured user input workflows
> **MCP Validated**: 2026-03-03

## When to Use

- Collecting multiple inputs before processing (batch submission)
- Preventing reruns on every keystroke (form groups widgets)
- Building modal confirmation or edit dialogs
- Validating user input before saving to database

## Implementation

```python
import streamlit as st
from datetime import date

# --- Basic Form ---
# st.form prevents reruns until Submit is clicked
with st.form("new_order_form", clear_on_submit=True):
    st.subheader("New Order")

    col1, col2 = st.columns(2)
    with col1:
        customer = st.text_input("Customer Name", key="f_customer")
        email = st.text_input("Email", key="f_email")
    with col2:
        product = st.selectbox("Product", ["Widget A", "Widget B", "Widget C"])
        quantity = st.number_input("Quantity", min_value=1, max_value=1000, value=1)

    order_date = st.date_input("Order Date", value=date.today())
    notes = st.text_area("Notes", max_chars=500)

    submitted = st.form_submit_button("Submit Order", type="primary")

    if submitted:
        # Validation
        errors = []
        if not customer:
            errors.append("Customer name is required")
        if not email or "@" not in email:
            errors.append("Valid email is required")
        if quantity < 1:
            errors.append("Quantity must be at least 1")

        if errors:
            for error in errors:
                st.error(error)
        else:
            st.success(f"Order submitted for {customer}: {quantity}x {product}")
            # save_order(customer, email, product, quantity, order_date, notes)
```

## Dialog Pattern

```python
@st.dialog("Confirm Delete", width="small")
def confirm_delete(item_name: str):
    """Modal dialog for confirming destructive actions."""
    st.warning(f"Are you sure you want to delete **{item_name}**?")
    st.caption("This action cannot be undone.")

    col1, col2 = st.columns(2)
    with col1:
        if st.button("Cancel", use_container_width=True):
            st.rerun()
    with col2:
        if st.button("Delete", type="primary", use_container_width=True):
            st.session_state.items.remove(item_name)
            st.session_state.deleted = item_name
            st.rerun()

# Trigger from main app
for item in st.session_state.get("items", []):
    col1, col2 = st.columns([4, 1])
    col1.write(item)
    if col2.button("Delete", key=f"del_{item}"):
        confirm_delete(item)
```

## Edit Dialog with Pre-populated Values

```python
@st.dialog("Edit Product", width="medium")
def edit_product(product_id: int):
    product = st.session_state.products[product_id]

    name = st.text_input("Name", value=product["name"])
    price = st.number_input("Price", value=product["price"], format="%.2f")
    active = st.checkbox("Active", value=product["active"])

    if st.button("Save Changes", type="primary"):
        st.session_state.products[product_id] = {
            "name": name,
            "price": price,
            "active": active,
        }
        st.rerun()
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `clear_on_submit` | `False` | Reset form fields after submit |
| `border` | `True` | Show form border |
| Dialog `width` | `"small"` | `"small"` (500px), `"medium"` (750px), `"large"` (1280px) |
| Dialog `dismissible` | `True` | Allow closing via ESC or clicking outside |

## Validation Pattern

```python
def validate_form(data: dict) -> list[str]:
    """Return list of error messages. Empty list = valid."""
    errors = []
    if not data.get("name"):
        errors.append("Name is required")
    if len(data.get("name", "")) > 100:
        errors.append("Name must be under 100 characters")
    if data.get("price", 0) <= 0:
        errors.append("Price must be positive")
    if data.get("email") and "@" not in data["email"]:
        errors.append("Invalid email format")
    return errors

# Usage in form
if submitted:
    errors = validate_form({"name": name, "price": price, "email": email})
    if errors:
        for e in errors:
            st.error(e)
    else:
        save_record(name, price, email)
        st.success("Saved!")
```

## Form vs. Dialog Decision

| Use Case | Choose |
|----------|--------|
| Multiple fields, batch submission | `st.form` |
| Inline editing on the page | `st.form` |
| Confirmation before action | `@st.dialog` |
| Pop-up edit/create workflow | `@st.dialog` |
| Nested forms | Not supported -- use dialog |

## See Also

- [Components](../concepts/components.md)
- [State Management](../concepts/state-management.md)
- [Data Dashboard](../patterns/data-dashboard.md)
