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

      @broker Keyword.get(opts, :broker, GenPool.DefaultBroker)
      @backend Keyword.get(opts, :backend, %GenPool.Backend.Ane{})
      @pool_size Keyword.get(opts, :pool_size, 5)

      @doc false
      def start_link(opts \\ [], process_opts \\ []) do
        # GenServer.start_link(GenPool.ProcessManager, opts, process_opts)
        spawn_link(fn ->
          Process.register(self(), process_opts[:name] || __MODULE__)

          unless Process.whereis(@broker) do
            @broker.start_link(opts)
          end

          backend = GenPool.Backend.new(@backend)

          for _i <- 1..@pool_size do
            __start_child__(backend, self(), opts)
          end

          GenPool.cast(__MODULE__, {:__init__, opts})

          __main_heartbeat__(backend, opts)
        end)
      end

      def __broker__, do: @broker

      defp __main_heartbeat__(backend, opts) do
        receive do
          {:DOWN, _, :process, _, reason} ->
            __start_child__(backend, self(), opts)

            __main_heartbeat__(backend, opts)
        end
      end

      defp __start_child__(backend, parent_pid, opts) do
        spawn_monitor(fn ->
          tag = make_ref()

          __process_loop__(tag, backend, parent_pid, opts)
        end)
      end

      defp __process_loop__(tag, backend, parent_pid, opts) do
        {:await, ^tag, _} = :sbroker.async_ask_r(@broker, self(), {self(), tag})

        receive do
          {^tag, {:go, ref, {:cast, origin_pid, {:__stop__, reason}}, _, _}} ->
            state = GenPool.Backend.get(backend)

            {:stop, reason, state}
            |> __handle_reply__(backend, parent_pid, state, origin_pid, ref)

            __process_loop__(tag, backend, parent_pid, opts)

          {^tag, {:go, ref, {:cast, origin_pid, {:__continue__, params}}, _, _}} ->
            state = GenPool.Backend.get(backend)

            handle_continue(params, state)
            |> __handle_reply__(backend, parent_pid, state, origin_pid, ref)

            __process_loop__(tag, backend, parent_pid, opts)

          {^tag, {:go, ref, {:cast, _from, {:__init__, opts}}, _, _}} ->
            state = GenPool.Backend.get(backend)

            case init(opts) do
              {:ok, new_state} ->
                GenPool.Backend.put(backend, new_state, state)

              {:ok, new_state, {:continue, params}} ->
                GenPool.Backend.put(backend, new_state, state)
                GenPool.cast(__MODULE__, {:__continue__, params})
            end

            __process_loop__(tag, backend, parent_pid, opts)

          {^tag, {:go, ref, {:call, origin_pid, :__get_state__}, _, _}} ->
            state = GenPool.Backend.get(backend)

            {:reply, state, state}
            |> __handle_reply__(backend, parent_pid, state, origin_pid, ref)

            __process_loop__(tag, backend, parent_pid, opts)

          {^tag, {:go, ref, {:call, origin_pid, params}, _, _}} ->
            state = GenPool.Backend.get(backend)

            handle_call(params, origin_pid, state)
            |> __handle_reply__(backend, parent_pid, state, origin_pid, ref)

            __process_loop__(tag, backend, parent_pid, opts)

          {^tag, {:go, ref, {:cast, origin_pid, params}, _, _}} ->
            state = GenPool.Backend.get(backend)

            handle_cast(params, state)
            |> __handle_reply__(backend, parent_pid, state, origin_pid, ref)

            __process_loop__(tag, backend, parent_pid, opts)

          {:EXIT, _pid, reason} ->
            state = GenPool.Backend.get(backend)

            terminate(reason, state)
            exit(reason)

          message ->
            state = GenPool.Backend.get(backend)

            handle_info(message, state)
            |> __handle_reply__(backend, parent_pid, state)

            __process_loop__(tag, backend, parent_pid, opts)
        end
      end

      defp __handle_reply__(reply, backend, parent_pid, prev_state, origin_pid \\ nil, ref \\ nil) do
        case reply do
          {:reply, response, state} ->
            GenPool.Backend.put(backend, state, prev_state)

            if not is_nil(origin_pid) and not is_nil(ref) do
              send(origin_pid, {ref, response})
            end

          {:reply, response, state, _opts} ->
            GenPool.Backend.put(backend, state, prev_state)

            if not is_nil(origin_pid) and not is_nil(ref) do
              send(origin_pid, {ref, response})
            end

          {:stop, reason, state, _opts} ->
            GenPool.Backend.put(backend, state, prev_state)
            Process.exit(parent_pid, reason)

          {:stop, reason, state} ->
            GenPool.Backend.put(backend, state, prev_state)
            Process.exit(parent_pid, reason)

          {:noreply, state} ->
            GenPool.Backend.put(backend, state, prev_state)

          {:noreply, state, _opts} ->
            GenPool.Backend.put(backend, state, prev_state)
        end

        :ok
      end

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
    end
  end

  def start_link(gen_pool, init_args \\ [], opts \\ []) do
    gen_pool.start_link(init_args, opts)
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
