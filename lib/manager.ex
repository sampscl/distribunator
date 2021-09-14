#
# Distribunator.Manager

defmodule Distribunator.Manager do
  @moduledoc """
  The Distribunator.Manager:
  1. Makes sure all distributed nodes are `Node.connect()`ed
  """
  use GenServer
  require Distribunator.Distributed

  ##############################
  # API
  ##############################

  @doc """
  Start the genserver with a list of nodes to connect to and monitor
  ## Parameters
  - `absent_nodes` The list of nodes (each passable to `Node.connect`) that this
    GenServer will connect to and monitor

  ## Returns
  - See `GenServer::on_start`
  """
  def start_link(absent_nodes \\ []) do
    GenServer.start_link(__MODULE__, absent_nodes, [name: __MODULE__])
  end

  @doc """
  Connect to one or more nodes that are not currently connected or monitored

  ## Parameters
  - `nodes` A single node or list of node atoms to connect and monitor

  ## Returns
  - `:ok` All is well, the nodes are being connected and monitored
  - `{:error, reason}` Failed for reason
  """
  def connect(nodes), do: Distribunator.Distributed.call({:connect, nodes})

  defmodule State do
    @moduledoc false
    defstruct [
      absent_nodes: [], # list of nodes we're not connected to but should be
      present_nodes: [] # list nodes we are connected to and monitoring
    ]
  end

  ##############################
  # GenServer Callbacks
  ##############################

  @impl GenServer
  def init(absent_nodes) do
    Distribunator.Distributed.register()
    send(self(), :reconcile)
    {:ok, %State{absent_nodes: absent_nodes}}
  end

  @impl GenServer
  def handle_call({:connect, nodes}, _from, state) do
    {updated_state, result} = do_connect(state, List.wrap(nodes))
    {:reply, result, updated_state}
  end

  @impl GenServer
  def handle_info(:reconcile, state) do
    {:noreply, do_reconcile(state)}
  end

  @impl GenServer
  def handle_info({:nodedown, n}, state) do
    new_absent_nodes = [n| state.absent_nodes] |> Enum.uniq()
    new_present_nodes = Enum.reject(state.present_nodes, n)

    Process.send_after(self(), :reconcile, 5_000)

    new_state =
      state
      |> Map.put(:absent_nodes, new_absent_nodes)
      |> Map.put(:present_nodes, new_present_nodes)

    {:noreply, new_state}
  end

  ##############################
  # Internal Calls
  ##############################

  def do_reconcile(%State{absent_nodes: [] } = state), do: state
  def do_reconcile(%State{absent_nodes: absent_nodes, present_nodes: present_nodes} = state) do

    {new_absent_nodes, new_present_nodes} = Enum.reduce(absent_nodes, {[], present_nodes}, fn(absent_node, {acc_absent, acc_present}) ->
      if Node.connect(absent_node) && Node.monitor(absent_node, true) do
        # was previously absent, is now present
        {acc_absent, [absent_node| acc_present]}
      else
        # was previously absent, still is absent
        {[absent_node| acc_absent], acc_present}
      end
    end)

    if Enum.any?(new_absent_nodes) do
      # try again in a little while
      Process.send_after(self(), :reconcile, 5_000)
    end

    state
    |> Map.put(:absent_nodes, new_absent_nodes)
    |> Map.put(:present_nodes, new_present_nodes)
  end

  def do_connect(%State{absent_nodes: absent_nodes, present_nodes: present_nodes} = state, new_nodes) do
    if Enum.any?(new_nodes, fn(node) -> node in absent_nodes or node in present_nodes end) do
      {state, {:error, "duplicate node"}}
    else
      send(self(), :reconcile)
      {Map.put(state, :absent_nodes, absent_nodes ++ new_nodes), :ok}
    end
  end
end
