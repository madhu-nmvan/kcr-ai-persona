# When to Mock

Mock at **system boundaries** only — processes you do not own:

- External APIs (payment, LLM, email, etc.)
- Databases (sometimes — prefer a real test database)
- Time/randomness
- File system (sometimes — prefer pytest's `tmp_path` over mocking `open`)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

A syntactically correct patch of your own package (`mocker.patch("your_package...")`)
is still a red flag: the problem is the target, not the technique.

## Designing for Mockability

At system boundaries, design interfaces that are easy to fake:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```python
# Easy to fake
async def process_payment(order: Order, payment_client: PaymentClient) -> Receipt:
    return await payment_client.charge(order.total_cents)

# Hard to fake
async def process_payment(order: Order) -> Receipt:
    client = StripeClient(os.environ["STRIPE_API_KEY"])
    return await client.charge(order.total_cents)
```

DI applies at boundaries only. Internal collaborators are imported and called
directly — injecting everything is ceremony, not testability.

**2. Define the boundary as a Protocol**

Structural typing lets a fake satisfy the interface without inheritance,
and mypy verifies both the real client and the fake against it:

```python
class PaymentClient(Protocol):
    async def charge(self, amount_cents: int) -> Receipt: ...
```

**3. Prefer SDK-style interfaces over generic fetchers**

Create specific methods for each external operation instead of one generic
function with conditional logic:

```python
# GOOD: Each method is independently fakeable
class UserApi:
    def __init__(self, http: httpx.AsyncClient) -> None:
        self._http = http

    async def get_user(self, user_id: str) -> User: ...
    async def get_orders(self, user_id: str) -> list[Order]: ...
    async def create_order(self, data: OrderCreate) -> Order: ...

# BAD: Faking requires conditional logic inside the fake
class Api:
    async def fetch(self, endpoint: str, **options: Any) -> Any: ...
```

The SDK approach means:

- Each fake method returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per operation

**4. Inject time and randomness**

Don't patch `datetime.now` or `random` globally — pass them in at the boundary:

```python
async def create_session(user: User, clock: Callable[[], datetime]) -> Session:
    return Session(user_id=user.id, started_at=clock())

# In tests: create_session(user, clock=lambda: datetime(2026, 1, 1, tzinfo=UTC))
# For randomness: accept rng: random.Random and pass random.Random(42) in tests
```

## If you must patch

Sometimes a boundary can't be injected (third-party code, legacy call sites).
Two rules make patching survivable:

**Patch where the name is used, not where it is defined.** Patching the
definition site silently patches nothing:

```python
# orders/checkout.py does: from payments.client import stripe_client

mocker.patch("orders.checkout.stripe_client")   # GOOD: the name checkout looks up
mocker.patch("payments.client.stripe_client")   # BAD: checkout still sees the real one
```

**Always use autospec.** A plain `Mock` accepts calls to methods that no
longer exist, so tests stay green while the real interface drifts:

```python
mocker.patch("orders.checkout.stripe_client", autospec=True)
```
