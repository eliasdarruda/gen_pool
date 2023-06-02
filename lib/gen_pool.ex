defmodule GenPool do
  @moduledoc """
  Documentation for `GenPool`.
  """

  @type new_state :: term

  @callback init(init_arg :: term) ::
              {:ok, state}
              | {:ok, state, timeout | :hibernate | {:continue, continue_arg :: term}}
              | :ignore
              | {:stop, reason :: any}
            when state: any

  @callback handle_call(request :: term, pid(), state :: term) ::
              {:reply, reply, new_state}
              | {:reply, reply, new_state,
                 timeout | :hibernate | {:continue, continue_arg :: term}}
              | {:noreply, new_state}
              | {:noreply, new_state, timeout | :hibernate | {:continue, continue_arg :: term}}
              | {:stop, reason, reply, new_state}
              | {:stop, reason, new_state}
            when reply: term, new_state: term, reason: term

  @callback handle_cast(request :: term, state :: term) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout | :hibernate | {:continue, continue_arg :: term}}
              | {:stop, reason :: term, new_state}

  @callback handle_info(msg :: :timeout | term, state :: term) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout | :hibernate | {:continue, continue_arg :: term}}
              | {:stop, reason :: term, new_state}
            when new_state: term

  @callback handle_continue(continue_arg, state :: term) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout | :hibernate | {:continue, continue_arg}}
              | {:stop, reason :: term, new_state}
            when new_state: term, continue_arg: term

  @callback terminate(reason, state :: term) :: term
            when reason: :normal | :shutdown | {:shutdown, term} | term

  @optional_callbacks terminate: 2,
                      handle_info: 2,
                      handle_cast: 2,
                      handle_call: 3,
                      handle_continue: 2

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour GenPool

      @default_opts [
        external_broker?: Keyword.get(opts, :external_broker?, false),
        shared_state?: Keyword.get(opts, :shared_state?, true),
        broker: Keyword.get(opts, :broker, GenPool.DefaultBroker),
        backend: Keyword.get(opts, :backend, %GenPool.Backend.Ane{}),
        pool_size: Keyword.get(opts, :pool_size, 5),
        pool_module: __MODULE__
      ]

      @doc false
      def start_link(opts, process_opts \\ []) do
        GenServer.start_link(
          GenPool.ProcessManager,
          opts,
          process_opts
        )
      end

      def __default_opts__, do: @default_opts
      def __broker__, do: @default_opts[:broker]

      @doc false
      def handle_call(params, _from, _state) do
        raise "GenPool handle_call/3 not implemented for #{inspect(params)}"
      end

      @doc false
      def handle_cast(params, _state) do
        raise "GenPool handle_cast/2 not implemented for #{inspect(params)}"
      end

      @doc false
      def handle_info(params, _state) do
        raise "GenPool handle_info/2 not implemented for #{inspect(params)}"
      end

      @doc false
      def terminate(_reason, _state) do
        raise "GenPool terminate/2 not implemented"
      end

      @doc false
      def handle_continue(params, _state) do
        raise "GenPool handle_continue/2 not implemented for #{inspect(params)}"
      end

      defoverridable GenPool
      defoverridable(start_link: 1, start_link: 2)
    end
  end

  def start_link(gen_pool, init_opts \\ [], process_opts \\ []) do
    default_opts = gen_pool.__default_opts__()
    opts = Keyword.merge([client_opts: init_opts], default_opts)

    gen_pool.start_link(opts, Keyword.merge(process_opts, name: default_opts[:pool_module]))
  end

  def call(gen_pool, params) do
    gen_pool.__broker__()
    |> do_call(params)
  end

  def cast(gen_pool, params) do
    gen_pool.__broker__()
    |> do_cast(params)
  end

  def stop(gen_pool, reason \\ :shutdown) do
    gen_pool.__broker__()
    |> do_cast({:__stop__, reason})
  end

  def get_state(gen_pool) do
    gen_pool.__broker__()
    |> do_call(:__get_state__)
  end

  def get_children(gen_pool) do
    GenServer.call(gen_pool, :get_children)
  end

  defp do_cast(broker, params) do
    case :sbroker.async_ask(broker, {:cast, self(), params}) do
      {:drop, _time} -> {:error, :too_many_requests}
      _ -> :ok
    end
  end

  defp do_call(broker, params) do
    case :sbroker.ask(broker, {:call, self(), params}) do
      {:go, ref, worker, _, _queue_time} ->
        monitor = Process.monitor(worker)

        receive do
          {^ref, result} ->
            Process.demonitor(monitor, [:flush])
            result

          {:DOWN, ^monitor, _, _, reason} ->
            {:error, reason}
        end

      {:drop, _time} ->
        {:error, :too_many_requests}
    end
  end
end
