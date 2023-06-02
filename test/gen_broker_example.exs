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

  def add(value) do
    GenPool.call(__MODULE__, {:add, value})
  end

  def add_casting(value) do
    GenPool.cast(__MODULE__, {:add, value})
  end

  def get_state() do
    GenPool.get_state(__MODULE__)
  end

  def stop do
    GenPool.stop(__MODULE__)
  end

  def start_link(opts \\ []) do
    GenPool.start_link(__MODULE__, opts, [])
  end
end
