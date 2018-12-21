defmodule Mix.Tasks.Bonny.Gen.Manifest do
  @moduledoc """
  Generates the Kubernetes YAML manifest for this operator
  """

  use Mix.Task
  alias Bonny.Operator

  @default_opts [namespace: "default"]
  @switches [out: :string, namespace: :string]
  @aliases [o: :out, n: :namespace]

  @shortdoc "Generate Kubernetes YAML manifest for this operator"
  def run(args) do
    Mix.Task.run("loadpaths", args)

    {opts, _, _} =
      Mix.Bonny.parse_args(args, @default_opts, switches: @switches, aliases: @aliases)

    resource_manifests =
      Operator.crds() ++
        [
          Operator.cluster_role(),
          Operator.service_account(opts[:namespace]),
          Operator.cluster_role_binding(opts[:namespace]),
          Operator.deployment(opts[:namespace])
        ]

    manifest =
      resource_manifests
      |> Enum.map(fn m -> ["---\n", Poison.encode!(m, pretty: true), "\n"] end)
      |> List.flatten()

    out = opts[:out] || "manifest.yaml"

    Mix.Bonny.render(manifest, out)
  end
end
