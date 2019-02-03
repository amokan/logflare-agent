defmodule LFAgent.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children =
      Application.get_env(:lfagent, :sources)
      |> Enum.map(fn %{path: path, source: source} ->
        worker_id = String.to_atom(path)
        worker(LFAgent.Main, [%{id: worker_id, filename: path, source: source}], id: worker_id)
      end)

    opts = [strategy: :one_for_one, name: LFAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
