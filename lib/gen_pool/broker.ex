defmodule GenPool.Broker do
  @moduledoc """
  Documentation for `GenPool.Broker`.
  """

  @type queue_type :: :fifo | :lifo

  @callback client_queue :: [
              queue_type: queue_type,
              timeout: pos_integer,
              min: pos_integer,
              max: pos_integer
            ]
  @callback process_queue :: %{
              queue_type: queue_type,
              timeout: pos_integer,
              min: pos_integer,
              max: pos_integer
            }

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour GenPool.Broker
      @behaviour :sbroker

      @default_client_timeout Keyword.get(opts, :timeout, 5_000)
      @default_client_min Keyword.get(opts, :min_requests, 0)
      @default_client_max Keyword.get(opts, :max_requests, :infinity)

      def start_link(opts) do
        :sbroker.start_link({:local, __MODULE__}, __MODULE__, opts, [])
      end

      def process_queue do
        [
          queue_type: :filo,
          timeout: :infinity
        ]
      end

      def client_queue do
        [
          queue_type: :fifo,
          timeout: @default_client_timeout,
          min: @default_client_min,
          max: @default_client_max
        ]
      end

      def init(_opts) do
        client_queue_opts = client_queue()
        process_queue_opts = process_queue()

        sbroker_client_queue = %{
          drop: :drop,
          out: _get_queue_type(Keyword.fetch!(client_queue_opts, :queue_type)),
          timeout: Keyword.fetch!(client_queue_opts, :timeout),
          min: Keyword.fetch!(client_queue_opts, :min),
          max: Keyword.fetch!(client_queue_opts, :max)
        }

        sbroker_process_client_queue = %{
          drop: :drop,
          out: _get_queue_type(Keyword.fetch!(client_queue_opts, :queue_type)),
          timeout: Keyword.fetch!(client_queue_opts, :timeout)
        }

        {:ok,
         {{:sbroker_timeout_queue, sbroker_client_queue},
          {:sbroker_drop_queue, sbroker_process_client_queue}, []}}
      end

      defp _get_queue_type(:fifo), do: :out
      defp _get_queue_type(:filo), do: :out_r

      defoverridable(GenPool.Broker)
    end
  end
end
