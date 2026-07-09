# Database & schema

Postgres in production, SQLite for tests. SQLAlchemy 2.0 with typed
`Mapped` / `mapped_column` — no legacy `Column` declarations. One engine per
process, initialized in `db/engine.py`. Services receive a `Session` (or
`AsyncSession`); they never create engines or sessions themselves.

Schema changes go through Alembic migrations — never `create_all` outside tests.

## IDs

Integer identity primary keys. No UUID primary keys.

```python
id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
```

If an id crosses a trust boundary (API, UI, logs), expose a separate opaque
key column — don't change the PK.

## Timestamps

Always tz-aware UTC, `timestamptz` in Postgres. Naive `datetime` never enters
the ORM.

```python
created_at: Mapped[datetime] = mapped_column(
    DateTime(timezone=True), server_default=func.now()
)
```

## Enums

Stored as portable text, not native Postgres enums — keeps PG and SQLite
schemas identical and makes adding members a data change, not a migration:

```python
status: Mapped[RunStatus] = mapped_column(Enum(RunStatus, native_enum=False))
```

## Vectors

pgvector with the dimension pinned in the schema. Every embedding row carries
the model that produced it — embeddings without provenance are unqueryable
after a model swap:

```python
embedding: Mapped[list[float]] = mapped_column(Vector(1536))
embedding_model: Mapped[str] = mapped_column(Text)
```

On SQLite, fall back to JSON text and compute similarity in Python. Query
Postgres with cosine distance (`.cosine_distance()`); index with HNSW once
row counts justify it.

## JSON payloads (agent state, messages)

`JSONB` in Postgres, `JSON` type in SQLAlchemy. In-place mutation of a loaded
dict is invisible to change tracking and silently loses writes — reassign the
attribute, or declare the column with `MutableDict.as_mutable(JSONB)`.

## Soft deletes

Nullable tz-aware `deleted_at` column. Don't actually delete rows.

## Money & token costs

Integers only — token costs in micro-cents, prices in cents. Floats never
touch a money column. Display through `format_price()` in `lib/utils` — it
handles the "Free" case for `0` / `None`.
