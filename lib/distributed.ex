defmodule Distribunator.Distributed do
  @moduledoc """
  Utilities supporting process distribution
  """

  @doc """
  Get a single pid of a distributed name. If there are multiple pids registered
  with the same name, a random one is returned.

  ## Parameters
  - name The distributed name

  ## Returns
  - `{:ok, pid}` Success
  - `{:error, reason}` Failure and reason
  """
  @spec pid_of(any()) :: {:ok, pid()} | {:error, any()}
  def pid_of(name) do
    case name |> mangle_name() |> :pg.get_members() do
      [first| _] -> {:ok, first}
      _          -> {:error, "no pid"}
    end
  end

  @doc """
  Get the first pid of the current module
  ## Returns
  - `pid` The first registered pid of the calling module
  """
  @spec my_pid() :: pid()
  defmacro my_pid do
    quote do
      {:ok, pid} = Distribunator.Distributed.pid_of(__ENV__.module)
      pid
    end
  end

  @doc """
  Do a distributed call to the first registered pid of the calling module.

  ## Parameters
  - msg The message to send
  - timeout The timeout (ms)

  ## Returns
  - The result of GenServer.call()
  """
  defmacro call(msg, timeout \\ 5_000) do
    quote do
      {:ok, pid} = Distribunator.Distributed.pid_of(__ENV__.module)
      GenServer.call(pid, unquote(msg), unquote(timeout))
    end
  end

  @doc """
  Do a distributed cast to the first registered pid of the calling module.

  ## Parameters
  - msg The message to send

  ## Returns
  - The result of GenServer.cast()
  """
  defmacro cast(msg) do
    quote do
      {:ok, pid} = Distribunator.Distributed.pid_of(__ENV__.module)
      GenServer.cast(pid, unquote(msg))
    end
  end

  @doc """
  Get all pids sharing a distributed name

  ## Parameters
  - name The distributed name

  ## Returns
  - `{:ok, [pid()]}` Success, even if pid list is empty
  - `{:error, reason}` Failure and reason
  """
  @spec all_pids_of(any()) :: {:ok, [pid()]} | {:error, any()}
  def all_pids_of(name) do
    case name |> mangle_name() |> :pg.get_members() do
      pids when is_list(pids) -> {:ok, pids}
      _                       -> {:error, "no name"}
    end
  end

  @doc """
  Get all pids registered to the current module, easy shorthand

  ## Returns
  - `{:ok, [pid()]}` Success, even if pid list is empty
  - `{:error, reason}` Failure and reason
  """
  @spec all_pids_of() :: {:ok, [pid()]} | {:error, any()}
  defmacro all_pids_of do
    quote do
      Distribunator.Distributed.all_pids_of(__ENV__.module)
    end
  end

  @spec all_nodes_of(atom()) :: {:ok, [atom()]} | {:error, any()}
  @doc """
  Get all node atoms sharing an instance of a distributed name

  ## Parameters
  - name The distributed name

  ## Returns
  - `{:ok, [node_atom]}` Success, even if atom list is emtpy
  - `{:error, reason}` Failure and reason
  """
  def all_nodes_of(name) do
    case all_pids_of(name) do
      {:error, reason} -> {:error, reason}

      {:ok, pids} ->
        nodes =
          pids
          |> Enum.map(&(node(&1)))
          |> Enum.uniq()

        {:ok, nodes}
    end
  end

  @spec all_nodes_of() :: {:ok, [atom()]} | {:error, any()}
  @doc """
  Get all nodes having the current module registered, see all_nodes_of/1
  """
  defmacro all_nodes_of do
    quote do
      Distribunator.Distributed.all_nodes_of(__ENV__.module)
    end
  end

  @doc """
  Perform an :rpc.call/4 on the target node. The callback is called with the
  target function's return value from the context of the intermediate rpc pid.
  This allows the return value to be used before the target node sees that the
  caling pid exited. Useful for when the target node wants to monitor calling
  pids.

  ## Parameters
  - target_node The node on which to execute the function
  - mod The module atom to call the function on
  - func The function atom to call
  - args The argument list to function
  - callback The callback to call during rpc invocation after the target function
  returns but before the rpc call returns. Can be nil.

  ## Returns
  - `{:badrpc, reason}` RPC failed, for reason
  - `{:error, "no node"}` There were no nodes with name registered
  - any The result of `apply(mod, func, args)`
  """
  @spec do_node_rpc(atom(), atom(), atom(), list(), function()|nil) :: {:error, any()} | any()
  def do_node_rpc(target_node, mod, func, args, callback) do
    if target_node == node() do
      result = apply(mod, func, args)
      if callback, do: callback.(result)
      result
    else
      :rpc.call(target_node, __MODULE__, :do_node_rpc, [target_node, mod, func, args, callback])
    end
  end

  @doc """
  Perform an :rpc.call/4 on the first node having name registered on it.
  ## Parameters
  - name The distributed name
  - mod The module atom to call the function on
  - func The function atom to call
  - args The argument list to function
  - callback The callback to call during rpc invocation after the target function
  returns but before the rpc call returns. Can be nil.

  ## Returns
  - `{:badrpc, reason}` RPC failed, for reason
  - `{:error, "no node"}` There were no nodes with name registered
  - any The result of `apply(mod, func, args)`
  """
  @spec node_rpc(atom(), atom(), atom(), list(), function()|nil) :: {:error, any()} | any()
  def node_rpc(name, mod, func, args, callback) do
    case all_nodes_of(name) do
      {:error, reason} -> {:badrpc, reason}
      {:ok, []}        -> {:error, "no node"}
      {:ok, [node|_]}  -> do_node_rpc(node, mod, func, args, callback)
    end
  end

  @doc """
  Perform an :rpc.call/4 on the first node having the current module registered on it.
  ## Parameters
  - mod The module atom to call the function on
  - func The function atom to call
  - args The argument list to function
  - callback The callback to call during rpc invocation after the target function
  returns but before the rpc call returns. Can be nil.

  ## Returns
  - `{:badrpc, reason}` RPC failed, for reason
  - `{:error, "no node"}` There were no nodes with name registered
  - any The result of `apply(mod, func, args)`
  """
  @spec node_rpc(atom(), atom(), list(), function()|nil) :: {:error, any()} | any()
  defmacro node_rpc(mod, func, args, callback) do
    quote do
      Distribunator.Distributed.node_rpc(__ENV__.module, unquote(mod), unquote(func), unquote(args), unquote(callback))
    end
  end

  @doc """
  Register self() with a distributed name

  ## Parameters
  - name The distributed name

  ## Returns
  - `:ok`
  """
  @spec register(any()) :: :ok
  def register(name), do: register(name, self())

  @doc """
  Register a pid with a distributed name

  ## Parameters
  - name The distributed name
  - pid The pid

  ## Returns
  - `:ok`
  """
  @spec register(any(), pid()) :: :ok
  def register(name, pid) do
    mangled = mangle_name(name)
    :pg.join(mangled, pid)
    :ok
  end

  @doc """
  Register the current module and pid, easy shorthand
  """
  @spec register() :: :ok
  defmacro register do
    quote do
      Distribunator.Distributed.register(__ENV__.module)
    end
  end

  @doc """
  Get the registry of names and pids

  ## Returns
  - `[{name, {:ok, [pid]}}, ...]`
  """
  def registry do
    :pg.which_groups()
    |> Enum.reject(&(unmangle_name(&1) == nil))
    |> Enum.map(&({unmangle_name(&1), all_pids_of(unmangle_name(&1))}))
  end

  defp mangle_name(name), do: {__MODULE__, name}
  defp unmangle_name(name) do
    case name do
      {__MODULE__, real_name} -> real_name
      _ -> nil
    end
  end

end
