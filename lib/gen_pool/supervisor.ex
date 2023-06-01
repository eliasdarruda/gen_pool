defmodule GenPool.Supervisor do
  @doc """
  Documentation for `GenPool.Supervisor`.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: opts[:name])
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent
    }
  end

  @doc """
  Documentation for `init/1`.
  """
  @impl true
  def init(opts) do
    children = [
      GenPool.Broker.child_spec(opts)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
