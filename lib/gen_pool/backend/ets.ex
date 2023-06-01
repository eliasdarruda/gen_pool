defmodule GenPool.Backend.Ets do
  defstruct type: :ets, ref: nil
end

defimpl GenPool.Backend, for: GenPool.Backend.Ets do
  alias GenPool.Backend.Ets

  def new(_opts) do
    table = :ets.new(:gen_pool_state, [:public, read_concurrency: true, write_concurrency: :auto])

    %Ets{ref: table}
  end

  def put(%Ets{ref: table}, new_state) do
    :ets.insert(table, {:state, new_state})
  end

  def get(%Ets{ref: table}) do
    case :ets.lookup(table, :state) do
      [{:state, state}] -> state
      _ -> nil
    end
  end
end
