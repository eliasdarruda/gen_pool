defmodule ExampleGenPool do
  use GenPool, pool_size: 5

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
    {:reply, state.count + value, %State{state | count: state.count + value}}
  end

  def add(value) do
    GenPool.call(__MODULE__, {:add, value})
  end

  def add_casting(value) do
    GenPool.cast(__MODULE__, {:add, value})
  end
end
