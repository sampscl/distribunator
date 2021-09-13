defmodule Distribunator do
  @moduledoc """
  Library entrypoint
  """
  use Application

  @impl Application
  def start(_type, _args) do
    :pg.start_link()
    :ok = case :pg.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> {:error, error}
    end

    Supervisor.start_link(
      [
        {Distribunator.Manager, []}
      ],
      strategy: :one_for_one, name: __MODULE__)
  end
end
