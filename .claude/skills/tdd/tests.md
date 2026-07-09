# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```python
# GOOD: Tests observable behavior
async def test_user_can_checkout_with_valid_cart():
    cart = create_cart()
    cart.add(product)
    result = await checkout(cart, payment_method)
    assert result.status == "confirmed"
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test — several `assert` statements verifying one
  outcome are fine; verifying two unrelated behaviors is not

**The boundary rule**: Mock or fake only at process boundaries you do not own
(LLM APIs, payment gateways, clocks, network). Never patch your own modules
in order to observe them.

```python
# GOOD: Fake at the owned boundary, verify observable behavior
async def test_checkout_with_declined_card_leaves_order_unpaid(fake_payment_gateway):
    fake_payment_gateway.will_decline()
    result = await checkout(cart, payment_method)
    assert result.status == "payment_declined"
```

Prefer fakes (in-memory implementations of the boundary's interface) over
`MagicMock`: a fake enforces the contract; a `MagicMock` silently accepts any
call, including wrong ones.

**Fixtures follow the same rule**: fixtures build state only through public
APIs or boundary fakes. A fixture that patches internals or pre-seeds private
state is an implementation-detail test in disguise.

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```python
# BAD: Tests implementation details
async def test_checkout_calls_payment_service_process(mocker):
    mock_payment = mocker.patch("shop.checkout.payment_service")
    await checkout(cart, payment)
    mock_payment.process.assert_called_once_with(cart.total)
```

Red flags:

- Patching your own modules (`mocker.patch("your_package...")`)
- Testing private functions (`_helper`) directly
- Asserting on call counts, call order, or `call_args_list`
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of the interface

```python
# BAD: Bypasses interface to verify
async def test_create_user_saves_to_database(db_session):
    await create_user(name="Alice")
    row = await db_session.execute(
        text("SELECT * FROM users WHERE name = :name"), {"name": "Alice"}
    )
    assert row.first() is not None

# GOOD: Verifies through interface
async def test_create_user_makes_user_retrievable():
    user = await create_user(name="Alice")
    retrieved = await get_user(user.id)
    assert retrieved.name == "Alice"
```

**Tests that can never fail**: Everything is mocked, so the test only checks
that the mock returns what the mock was told to return.

```python
# BAD: Asserts the mock, not the code
async def test_get_exchange_rate(mocker):
    mocker.patch("rates.service.fetch_rate", return_value=1.35)
    assert await get_exchange_rate("USD", "CAD") == 1.35
```

**Tautological tests**: Expected value restates the implementation, so the
test passes by construction.

```python
# BAD: Expected value is recomputed the way the code computes it
def test_calculate_total_sums_line_items():
    items = [LineItem(price=10), LineItem(price=5)]
    expected = sum(i.price for i in items)
    assert calculate_total(items) == expected

# GOOD: Expected value is an independent, known literal
def test_calculate_total_sums_line_items():
    assert calculate_total([LineItem(price=10), LineItem(price=5)]) == 15
```

**The oracle rule**: Expected values are human-authored literals derived from
the spec — never computed by re-running the logic under test, and never
captured from the code's current output (a snapshot of today's behavior only
proves the code does what the code does).
