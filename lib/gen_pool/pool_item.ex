defmodule GenPool.PoolItem do
  @doc """
  Documentation for `GenPool.PoolItem`.
  """

  def init(backend, parent_pid, opts) do
    tag = make_ref()

    backend =
      if opts[:shared_state?] do
        backend
      else
        new_backend = GenPool.Backend.new(opts[:backend])

        do_init(new_backend, opts, opts[:client_opts])

        new_backend
      end

    event_loop(tag, backend, parent_pid, opts)
  end

  defp event_loop(tag, backend, parent_pid, opts) do
    {:await, ^tag, _} = :sbroker.async_ask_r(opts[:broker], self(), {self(), tag})

    # TODO: Implement sregulator https://hexdocs.pm/sbroker/
    # drop(Ref, Pid) ->
    # case sregulator:continue(Pid, Ref) of
    #     {go, Ref, Pid, _, _} ->
    #         % continue loop with same Ref as before
    #         loop(Ref, Pid);
    #     {stop, _} ->
    #         % process should stop its loop and Ref is removed from sregulator
    #         stop()
    # end.

    receive do
      {^tag, {:go, _ref, {:cast, _origin_pid, {:__stop__, reason}}, _, _}} ->
        state = GenPool.Backend.get(backend)

        {:stop, reason, state}
        |> do_no_reply(backend, parent_pid, state)

        event_loop(tag, backend, parent_pid, opts)

      {^tag, {:go, _ref, {:cast, _origin_pid, {:__continue__, params}}, _, _}} ->
        state = GenPool.Backend.get(backend)

        opts[:pool_module].handle_continue(params, state)
        |> do_no_reply(backend, parent_pid, state)

        event_loop(tag, backend, parent_pid, opts)

      {^tag, {:go, _ref, {:cast, _from, {:__init__, init_opts}}, _, _}} ->
        do_init(backend, opts, init_opts)

        event_loop(tag, backend, parent_pid, opts)

      {^tag, {:go, ref, {:call, origin_pid, :__get_state__}, _, _}} ->
        state = GenPool.Backend.get(backend)

        {:reply, state, state}
        |> do_reply(backend, parent_pid, state, origin_pid, ref)

        event_loop(tag, backend, parent_pid, opts)

      {^tag, {:go, ref, {:call, origin_pid, params}, _, _}} ->
        state = GenPool.Backend.get(backend)

        opts[:pool_module].handle_call(params, origin_pid, state)
        |> do_reply(backend, parent_pid, state, origin_pid, ref)

        event_loop(tag, backend, parent_pid, opts)

      {^tag, {:go, _ref, {:cast, _origin_pid, params}, _, _}} ->
        state = GenPool.Backend.get(backend)

        opts[:pool_module].handle_cast(params, state)
        |> do_no_reply(backend, parent_pid, state)

        event_loop(tag, backend, parent_pid, opts)

      {:EXIT, _pid, reason} ->
        state = GenPool.Backend.get(backend)

        opts[:pool_module].terminate(reason, state)
        exit(reason)

      message ->
        state = GenPool.Backend.get(backend)

        opts[:pool_module].handle_info(message, state)
        |> do_no_reply(backend, parent_pid, state)

        event_loop(tag, backend, parent_pid, opts)
    end
  end

  defp do_init(backend, opts, init_opts) do
    state = GenPool.Backend.get(backend)

    case opts[:pool_module].init(init_opts) do
      {:ok, new_state} ->
        GenPool.Backend.put(backend, new_state, state)

      {:ok, new_state, {:continue, params}} ->
        GenPool.Backend.put(backend, new_state, state)
        GenPool.cast(__MODULE__, {:__continue__, params})
    end
  end

  defp do_reply(reply, backend, parent_pid, prev_state, origin_pid, ref) do
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

      message ->
        do_no_reply(message, backend, parent_pid, prev_state)
    end

    :ok
  end

  defp do_no_reply(reply, backend, parent_pid, prev_state) do
    case reply do
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

      _ ->
        raise "Invalid reply: #{inspect(reply)}"
    end

    :ok
  end
end
