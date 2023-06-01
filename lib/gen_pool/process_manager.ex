defmodule GenPool.ProcessManager do
  @doc """
  Documentation for `GenPool.GenPoolProcessManager`.
  """

  use GenServer

  @impl true
  def init(opts) do
    unless Process.whereis(@broker) do
      @broker.start_link(opts)
    end

    backend = GenPool.Backend.new(@backend)

    for _i <- 1..@pool_size do
      __start_child__(backend, self(), opts)
    end

    GenPool.cast(__MODULE__, {:__init__, opts})

    __main_heartbeat__(backend, opts)

    {:ok, opts}
  end
end
