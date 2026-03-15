# bindable-engine

Zero-dependency Ruby gem implementing the Bindable pattern from the biological architecture.

## What this gem does

Provides autonomous domain components with a uniform 6-method interface (create, read, update, delete, list, execute), immutable ContextRecords, thread-safe registry, automatic MCP tool generation, and cell-membrane governance via MessageModerator.

## Key files

| File | Purpose |
|------|---------|
| `lib/bindable_engine.rb` | Entry point — requires all components |
| `lib/bindable_engine/result.rb` | Standalone Success/Failure Result monad |
| `lib/bindable_engine/bindable.rb` | 6-method interface module + DSL |
| `lib/bindable_engine/context_record.rb` | Immutable message envelope with JSON-LD |
| `lib/bindable_engine/bindable_registry.rb` | Thread-safe singleton registry |
| `lib/bindable_engine/bindable_tool_adapter.rb` | MCP tool definition generator + call router |
| `lib/bindable_engine/bindable_result_wrapper.rb` | Safe invocation with exception → Result mapping |
| `lib/bindable_engine/message_moderator.rb` | Cell membrane: authenticate → authorize → route → log |
| `lib/bindable_engine/service_node.rb` | Bounded context container |
| `lib/bindable_engine/context_bundle.rb` | Bundle definition value object |
| `lib/bindable_engine/context_assembler.rb` | Bundle resolution (parallel/sequential/lazy) |

## Relationship to cc-biological

This gem extracts the core Bindable infrastructure from `cc-biological`. After adoption, `cc-biological` becomes a thin consumer adding ecosystem-specific features (CedarAuthorizer, Entity, Aggregate, ValueObject, AgentSpawner, AgentSpec, MessageFabric).

## Conventions

- Zero runtime dependencies — pure Ruby stdlib only
- `BindableEngine::` namespace (not `LibraryBiological::`)
- `BindableEngine::Result` replaces `LibraryException::Result` (Dry::Monads)
- `SecureRandom.uuid` replaces `SecureRandom.uuid_v7` (no uuid_v7 gem)
- `Mutex` replaces `MonitorMixin` (simpler)
- No TypeStore/Enricher references (ecosystem-specific)

## Testing

```bash
bundle exec rspec
```
