defmodule GenPool.Broker do
  @behaviour :sbroker

  @default_timeout 5_000

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent
    }
  end

  def start_link(opts) do
    :sbroker.start_link({:local, __MODULE__}, __MODULE__, opts, [])
  end

  def init(opts) do
    # Make the "left" side of the broker a FIFO queue that drops the request after the timeout is reached.
    client_queue =
      {:sbroker_timeout_queue,
       %{
         out: :out,
         drop: :drop,
         timeout: Keyword.get(opts, :timeout, @default_timeout),
         min: Keyword.get(opts, :min_requests, 0),
         max: Keyword.get(opts, :max_requests, :infinity)
       }}

    # Make the "right" side of the broker a FIFO queue that has no timeout.
    worker_queue =
      {:sbroker_drop_queue,
       %{
         out: :out_r,
         drop: :drop,
         timeout: :infinity
       }}

    {:ok, {client_queue, worker_queue, []}}
  end
end
