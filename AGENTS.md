# AGENTS.MD

`crucible` is a Rails 8 + Inertia-Rails + Svelte app. The main developer environment is handled by `devenv`. To be able to access all the developer tooling, you must run `devenv shell` first.

## Rules
- Do not write raw database migrations. Defer to the `rails g migration ...` generator when creating new migrations.
