defmodule ManagerSpec do
  use ESpec

  describe "manager" do
    it "reconciles an empty list" do
      state = %Distribunator.Manager.State{absent_nodes: [], present_nodes: []}
      expect(Distribunator.Manager.do_reconcile(state)) |> to(eq(state))
    end

    it "detects duplicate absent connections" do
      state = %Distribunator.Manager.State{absent_nodes: [Node.self()], present_nodes: []}
      expect(Distribunator.Manager.do_connect(state, [Node.self()])) |> to(eq({state, {:error, "duplicate node"}}))
    end

    it "detects duplicate present connections" do
      state = %Distribunator.Manager.State{absent_nodes: [], present_nodes: [Node.self()]}
      expect(Distribunator.Manager.do_connect(state, [Node.self()])) |> to(eq({state, {:error, "duplicate node"}}))
    end
  end
end
