# GenPool

## WIP

A pooled process with the option to centralize state, decouple the message queue and handle backpressure using [sbroker](https://github.com/fishcakez/sbroker).

### The goal is to:

- Avoid having a single process queue becoming a bottleneck.
- Interact with the process as you would interact with any GenServer.
- Have ways to handle backpressure in the process requests.
- Having the option to keep a centralized state with atomicity even though the process is pooled.
- Decentralize message queue from the process implementation.

## Example

```Elixir
defmodule ExampleGenPool do
  use GenPool,
    pool_size: 5,
    shared_state?: true,
    external_broker?: false,
    broker: GenPool.DefaultBroker,
    backend: %GenPool.Backend.Ane{}

  defmodule State do
    defstruct count: 0
  end

  @impl true
  def init(_) do
    {:ok, %State{count: 0}}
  end

  @impl true
  def handle_call({:add, value}, _from, state) do
    {:reply, state.count + value, %State{state | count: state.count + value}}
  end

  @impl true
  def handle_cast({:add, value}, state) do
    {:noreply, %State{state | count: state.count + value}}
  end

  def start_link(opts \\ []) do
    GenPool.start_link(__MODULE__, opts, [])
  end

  def add(value) do
    GenPool.call(__MODULE__, {:add, value})
  end

  def add_casting(value) do
    GenPool.cast(__MODULE__, {:add, value})
  end
end
```

Optionally you can define your own broker with:

```Elixir
defmodule MyGenPoolBroker do
  use GenPool.Broker

  @impl true
  def process_queue do
    [
      queue_type: :filo,
      timeout: :infinity
    ]
  end

  @impl true
  def client_queue do
    [
      queue_type: :fifo,
      timeout: 10_000, # call timeout
      min: 0,

      # max value for backpressure
      # if the message queue reaches this value
      # it will throw {:error, :too_many_requests} on casts and calls
      max: :infinity
    ]
  end
end
```

Running in iex:

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
    {:gen_pool, "~> 0.1.0"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/gen_pool>.
