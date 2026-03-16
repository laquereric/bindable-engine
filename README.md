# bindable-engine

Biological component interface for Ruby. Zero-dependency implementation of the Bindable pattern: autonomous domain components with a uniform 6-method interface, immutable messages, thread-safe registry, automatic MCP tool generation, and cell-membrane governance.

## Installation

```ruby
gem "bindable-engine"
```

## Core Concepts

**Bindable** — the cell. Any class that includes `BindableEngine::Bindable` exposes exactly six methods: `create`, `read`, `update`, `delete`, `list`, `execute`. This uniform interface makes everything else possible.

**ContextRecord** — the message. An immutable, self-describing envelope carrying complete state. Any service node can process a ContextRecord without prior context. Each record is a JSON-LD document.

**Result** — a Success/Failure monad. Every operation returns a `BindableEngine::Result`, never raises. Error codes follow the MCP-BINDABLE spec: `:unauthorized`, `:forbidden`, `:not_found`, `:validation_error`, `:not_implemented`, `:internal_error`.

**MessageModerator** — the cell membrane. Every message entering or leaving a service node passes through its moderator, which authenticates, authorizes, routes, and logs.

**ServiceNode** — the organ. A collection of Bindables operating as an autonomous unit with its own moderator and communication gateway.

**BindableRegistry** — thread-safe singleton tracking all registered Bindables and their implemented methods.

## Usage

### Define a Bindable

```ruby
class UsersBindable
  include BindableEngine::Bindable
  include BindableEngine::BindableResultWrapper

  bind_as "users"
  describe_as "User management"
  describe_method :read, "Fetch a user by ID"
  describe_method :list, "List all users"

  def read(context_record)
    id = context_record.payload[:id]
    BindableEngine::Result.success({ id: id, name: "Alice" })
  end

  def list(context_record)
    BindableEngine::Result.success([{ id: "1", name: "Alice" }])
  end
end
```

### Send messages through a ServiceNode

```ruby
node = BindableEngine::ServiceNode.new(name: "app")
node.register(UsersBindable.new)

record = BindableEngine::ContextRecord.new(
  action: :read,
  target: "users",
  payload: { id: "42" }
)

result = node.send_message(record)
result.success? # => true
result.value!   # => { id: "42", name: "Alice" }
```

### Result monad

```ruby
# Success
result = BindableEngine::Result.success({ id: "1" })
result = BindableEngine::Result.success({ id: "1" }, metadata: { control: "CC1.1" })

# Failure
result = BindableEngine::Result.failure(code: :not_found, message: "User not found")

# Chaining
result.map { |value| transform(value) }
result.bind { |value| another_operation(value) }
```

### MCP tool generation

`BindableToolAdapter` converts any Bindable into MCP-compatible tool definitions. Each implemented method becomes a separate tool (e.g., `users_read`, `users_list`).

```ruby
adapter = BindableEngine::BindableToolAdapter.new(UsersBindable.new)
adapter.tool_definitions
# => [{ name: "users_read", description: "...", input_schema: {...} }, ...]

adapter.call("users_read", { id: "42" })
# => #<BindableEngine::Result success=true>
```

### Governance

Plug in authentication and authorization lambdas:

```ruby
node = BindableEngine::ServiceNode.new(
  name: "secure",
  authenticator: ->(record) { record.metadata[:token] == "valid" },
  authorizer: ->(record) { allowed_actions.include?(record.action) }
)
```

Failed auth returns `Result.failure(code: :unauthorized)` or `Result.failure(code: :forbidden)`.

### Persistence

Declare a persistence strategy and use the Store abstraction:

```ruby
class OrdersBindable
  include BindableEngine::Bindable
  include BindableEngine::BindableResultWrapper

  bind_as "orders"
  persists_with :memory  # :relational, :graph, :memory, :none

  def initialize
    @store = BindableEngine::Stores::MemoryStore.new
  end

  def create(context_record)
    @store.save(SecureRandom.uuid, context_record.payload)
  end

  def read(context_record)
    @store.find(context_record.payload[:id])
  end
end
```

Concrete store implementations: `MemoryStore` (this gem), `RelationalStore` (bindable-engine-rails), `GraphStoreAdapter` (bindable-ontology).

### Cross-domain references

`Ref` is a lazy pointer resolved through `Bindable#read`:

```ruby
ref = BindableEngine::Ref.new(target: "users", id: "42")
resolver = BindableEngine::RefResolver.new

result = resolver.resolve(ref)        # calls users#read
resolver.resolve_refs_in(nested_data) # walks structure, resolves all Refs
```

### JSON-LD serialization

```ruby
BindableEngine::Serializer.to_json_ld(
  { id: "1", name: "Alice" },
  context_url: "https://schema.org",
  type_name: "Person"
)
# => { "@context" => "https://schema.org", "@type" => "Person", "@id" => "1", "name" => "Alice" }
```

### Context bundles

Assemble rich context from multiple Bindables for LLM interaction points:

```ruby
assembler = BindableEngine::ContextAssembler.new(registry: BindableEngine::BindableRegistry.instance)

bundle = {
  id: "user-profile-context",
  assembly_mode: "parallel",  # parallel | sequential | lazy
  views: [
    { concept: "users", fields: [:id, :email, :name] },
    { concept: "profiles", includes: { presets: [:name, :temperature] } }
  ]
}

assembler.assemble(bundle)
# => { bundle: "user-profile-context", assembly_mode: "parallel", views: { "users" => {...}, "profiles" => {...} } }
```

## Components

| Class | Role |
|-------|------|
| `Bindable` | Module providing the 6-method interface |
| `BindableResultWrapper` | Exception-safe `safe_handle` that normalizes returns to Result |
| `Result` | Success/Failure monad (frozen, zero-dep) |
| `ContextRecord` | Immutable JSON-LD message envelope |
| `BindableRegistry` | Thread-safe singleton registry |
| `BindableToolAdapter` | MCP tool definition generator + call router |
| `MessageModerator` | Auth + routing + logging membrane |
| `ServiceNode` | Autonomous unit hosting Bindables + Moderator |
| `ContextBundle` | Immutable bundle definition (parallel/sequential/lazy) |
| `ContextAssembler` | Multi-Bindable context fetcher |
| `Store` | Abstract persistence interface |
| `Stores::MemoryStore` | Thread-safe in-memory store |
| `Ref` | Cross-domain lazy reference |
| `RefResolver` | Resolves Refs through the registry |
| `Serializer` | JSON-LD serialization helpers |

## Related gems

- **[bindable-engine-rails](https://github.com/laquereric/bindable-engine-rails)** — Rails integration (Railties, controllers, MCP tool generation)
- **[bindable-ontology](https://github.com/laquereric/bindable-ontology)** — RDF/SPARQL behind the Bindable interface
- **[vv-semantic-ui](https://github.com/laquereric/vv-semantic-ui)** — Ontology-driven UI generation from typed responses

## Development

```bash
bundle install
bundle exec rspec
```

126 specs, zero dependencies.

## License

MIT
