defmodule GenPool.ProcessManager do
  @doc """
  Documentation for `GenPool.GenPoolProcessManager`.
  """

  use GenServer

  alias GenPool.PoolItem

  @impl true
  def init(opts) do
    unless opts[:external_broker?] do
      opts[:broker].start_link(opts)
    end

    backend =
      if opts[:shared_state?] do
        GenPool.Backend.new(opts[:backend])
      end

    children =
      Enum.map(1..opts[:pool_size], fn _ ->
        {pid, _ref} = start_child(backend, self(), opts)
        pid
      end)

    if opts[:shared_state?] do
      GenPool.cast(opts[:pool_module], {:__init__, opts[:client_opts]})
    end

    {:ok, {backend, opts, children}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, _reason}, {backend, opts, children}) do
    {new_pid, _ref} = start_child(backend, self(), opts)
    new_children = children -- ([pid] ++ [new_pid])

    {:noreply, {backend, opts, new_children}}
  end

  @impl true
  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_children, _from, {backend, opts, children}) do
    {:reply, children, {backend, opts, children}}
  end

  defp start_child(backend, parent_pid, opts) do
    spawn_monitor(fn ->
      PoolItem.init(backend, parent_pid, opts)
    end)
  end
end
