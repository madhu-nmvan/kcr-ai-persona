# Python conventions

Enforced mechanically: `mypy --strict` and `ruff` run in CI and in the loop.
A convention the type-checker can't see is a suggestion; these are gates.

## Keyword-only for same-typed args

When a function has more than one parameter of the same type (e.g. multiple
`str` ids), force keyword arguments with the bare `*` marker — call sites
can't silently swap them:

```python
# BAD
def add_user_to_post(user_id: str, post_id: str) -> None: ...

# GOOD
def add_user_to_post(*, user_id: str, post_id: str) -> None: ...
```

`**kwargs` is not keyword-only — bare `**kwargs` in signatures is banned
outside decorators and thin adapter shims; it erases type-checking.

## No `Any`

Don't use `Any` and don't leave defs untyped — `mypy --strict` rejects both.
If unsure of a type, check the SQLAlchemy model or Pydantic schema and let
inference carry it.

One carve-out: payloads that genuinely arrive untyped (LLM output, external
JSON) may touch `Any` **at the boundary only**, and must convert to a
Pydantic model or `TypedDict` immediately. `dict[str, Any]` never travels
past the edge.

## Imports

Absolute imports from the package root — `from sttm_core.lib.utils import
format_price`. No parent-relative imports (`from ...lib import utils`);
single-dot relative within the same package is fine.
