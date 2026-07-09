# Services & testing

## Services need tests

Every service module must have an accompanying test file, mechanically
checkable: `services/coupon_service.py` ↔ `tests/services/test_coupon_service.py`.
No test file, no merge — this is a CI / loop gate, not a guideline.

## Tagged result pattern

For discriminated results from services (not validation), use frozen
dataclasses consumed with `match`:

```python
@dataclass(frozen=True)
class Ok(Generic[T]):
    value: T

@dataclass(frozen=True)
class Err:
    error: str

Result = Ok[T] | Err
```

```python
match await redeem_coupon(session, code):
    case Ok(coupon):
        ...
    case Err(error):
        ...
```

`Err` is for **expected domain failures** (invalid coupon, mapping not found).
Bugs and invariant violations still raise — never wrap them in `Err`.

Services never import FastAPI and never raise `HTTPException`. The API layer
maps `Err` to HTTP status codes; that mapping is the only place HTTP exists.

## Pytest setup

Services are tested against a **real database**, not a mocked db module
(deliberate divergence from the TypeScript original — see mocks.md boundary
rule). In-memory SQLite works because all column types are portable
(see database.md):

```python
@pytest.fixture
def session() -> Iterator[Session]:
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)  # the sanctioned test-only exception
    with Session(engine) as s:
        seed_base_data(s)
        yield s
```

Services receive the session as an argument, so the fixture injects directly —
no patching, no import-order traps.

LLM and other external clients are injected and replaced with fakes from
`tests/fakes/` — never patched into your own modules (see mocks.md).
