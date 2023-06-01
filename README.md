# GenPool

## WIP

A GenServer with a local state but with the messages pooled with sbroker.

The goal is to:

- Avoid having a single process queue becoming a bottleneck.
- Interact with the process as you would interact with any GenServer.
- Have ways to handle backpressure.
- Keep state atomicity even though the process is pooled.

```Elixir
iex(1)> ExampleGenPool.start_link()

iex(2)> ExampleGenPool.add(5)
5

iex(3)> ExampleGenPool.add_casting(5)
:ok

iex(4)> ExampleGenPool.add(5)
15
```

## Installation

This [package](https://hex.pm/packages/gen_pool) can be installed by adding `gen_pool` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gen_pool, "~> 0.0.1"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/gen_pool>.
