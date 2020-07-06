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

  def start_link(absent_nodes \\ []) do
    GenServer.start_link(__MODULE__, absent_nodes, [name: __MODULE__])
  end

  defmodule State do
    @moduledoc false
    defstruct [
      absent_nodes: [],
    ]
  end

  ##############################
  # GenServer Callbacks
  ##############################

  def init(absent_nodes) do
    Distribunator.Distributed.register()
    send(self(), :reconcile)
    {:ok, %State{absent_nodes: absent_nodes}}
  end

  def handle_info(:reconcile, state) do
    {:noreply, do_reconcile(state)}
  end

  def handle_info({:nodedown, n}, state) do
    new_absent_nodes = [n| state.absent_nodes] |> Enum.uniq()
    Process.send_after(self(), :reconcile, 5_000)
    new_state = Map.put(state, :absent_nodes, new_absent_nodes)
    {:noreply, new_state}
  end

  ##############################
  # Internal Calls
  ##############################

  def do_reconcile(state) do
    new_absent_nodes = Enum.reject(state.absent_nodes, fn(n) ->
      Node.connect(n) && Node.monitor(n, true)
    end)

    if Enum.any?(new_absent_nodes) do
      Process.send_after(self(), :reconcile, 5_000)
    end
    Map.put(state, :absent_nodes, new_absent_nodes)
  end
end
