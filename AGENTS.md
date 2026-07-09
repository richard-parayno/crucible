# AGENTS.MD

`crucible` is a Rails 8 + Inertia-Rails + Svelte app. The main developer environment is handled by `devenv`. To be able to access all the developer tooling, you must run `devenv shell` first.

## Rules
- Do not handwrite Rails code that can be scaffolded by the rails generator `rails g ...`.
- For database migrations, use the `rails g migration ...` generator. You are allowed to manually edit the generated migration as needed.
- Use `agent-browser` and the $agent-browser skill to visually test any changes to the frontend's visuals, layout, and hierarchy.
- The dev server is resource intensive. You are not allowed to run `bin/dev`. Assume that the user is already running it.

## Coding Standards
- Use skinny controllers, skinny models, and fat services.
