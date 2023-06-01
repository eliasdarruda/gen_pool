defmodule GenPool.Backend.Ane do
  defstruct ref: nil
end

defimpl GenPool.Backend, for: GenPool.Backend.Ane do
  alias GenPool.Backend.Ane, as: ANE

  def new(_opts) do
    table =
      Ane.new(:erlang.phash2(make_ref()),
        read_concurrency: true,
        write_concurrency: true,
        compressed: false
      )

    %ANE{ref: table}
  end

  def put(%ANE{ref: table}, new_state, prev_state) do
    unless prev_state == new_state do
      Ane.put(table, 1, new_state)
    end

    :ok
  end

  def get(%ANE{ref: table}) do
    {_ane, value} = Ane.get(table, 1)

    value
  rescue
    _ -> nil
  catch
    _ -> nil
  end
end
