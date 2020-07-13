# Distribunator

Utilities supporting process distribution across nodes and node connections.

## Installation

The package can be installed by adding `distribunator` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distribunator, "~> 0.1"}
  ]
end
```

## Use

Distribunator consists of two components: The `Distribunator.Manager` GenServer
and the `Distribunator.Distributed` utility module.

### Manager

The manager GenServer is optional. Its job is to maintain a list of nodes that
will be `Node.connect()`ed and  `Node.monitor()`ed. If any of those goes down,
the manager will periodically (5 seconds) try to reconnect.

### Utility Module

The utility module contains functions and macros that allow low-friction
node-agnostic pid lookup, call, and cast functionality.

### Example Usage

Starting the manager from a module-based supervisor:
```elixir
defmodule MySupervisor  do
  @moduledoc """
  Supervisor some stuff
  """
  use Supervisor

  def start_link(args), do: Supervisor.start_link(__MODULE__, [args], name: __MODULE__)

  def init([args]) do
    Distributed.register()
    children_list = children()
    Supervisor.init(children_list, [strategy: :one_for_one])
  end

  def children do
    distributed_node_list = [String.to_atom("app1@remote_node1"), String.to_atom("app2@remote_node2")]
    [
      Supervisor.child_spec({Distribunator.Manager, distributed_node_list}, restart: :transient),
    ]
  end
end
```

A GenServer that is Distribunated
```elixir
defmodule MyWorker do
  @moduledoc """
  Do some work.
  """
  use GenServer
  require Distributed

  ##############################
  # API
  ##############################

  @doc """
  Do some foo-ing. Calling this API will lookup the first pid registered with
  the MyWorker module and perform a GenServer.call on it, returning the result.
  """
  def foo, do: Distributed.call(:foo)

  def start_link(:ok) do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  defmodule State do
    @moduledoc false
    defstruct [
    ]
  end

  ##############################
  # GenServer Callbacks
  ##############################

  @impl true
  def init(:ok) do
    # Register this module and pid with Distribunator so it can be called from anywhere
    Distributed.register()
    {:ok, %State{}}
  end

  @impl true
  def handle_call(:foo, _from, state) do
    {:reply, :ok, state}
  end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/distribunator](https://hexdocs.pm/distribunator).
