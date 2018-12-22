defmodule Mix.Tasks.Bonny.Gen.Manifest do
  @moduledoc """
  Generates the Kubernetes YAML manifest for this FUCK

  ## Examples

  The `image` switch is required.

  Options:
  * --image (docker image to deploy)
  * --namespace (of service account and deployment; defaults to "default")
  * --out (path to save manifest; defaults to "manifest.yaml")

  *Deploying to kubernetes:*

  ```shell

  docker build -t $(YOUR_IMAGE_NAME) .
  docker push $(YOUR_IMAGE_URL):latest

  mix bonny.gen.manifest --image $(YOUR_IMAGE_URL):latest --namespace default
  kubectl apply -f manifest.yaml -n default
  ```
  """

  use Mix.Task
  alias Bonny.Operator

  @default_opts [namespace: "default"]
  @switches [out: :string, namespace: :string, image: :string]
  @aliases [o: :out, n: :namespace, i: :image]

  @shortdoc "Generate Kubernetes YAML manifest for this operator"
  def run(args) do
    Mix.Task.run("loadpaths", args)

    {opts, _, _} =
      Mix.Bonny.parse_args(args, @default_opts, switches: @switches, aliases: @aliases)

    validate_opts!(opts)

    resource_manifests =
      Operator.crds() ++
        [
          Operator.cluster_role(),
          Operator.service_account(opts[:namespace]),
          Operator.cluster_role_binding(opts[:namespace]),
          Operator.deployment(opts[:image], opts[:namespace])
        ]

    manifest =
      resource_manifests
      |> Enum.map(fn m -> ["---\n", Poison.encode!(m, pretty: true), "\n"] end)
      |> List.flatten()

    out = opts[:out] || "manifest.yaml"

    Mix.Bonny.render(manifest, out)
  end

  defp validate_opts!(opts) when is_list(opts), do: opts |> Enum.into(%{}) |> validate_opts!
  defp validate_opts!(%{image: _image}), do: true
  defp validate_opts!(_) do
    raise_with_help("Invalid arguments.")
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix bonny.gen.manifest expects a docker image name. You may optionally provide a namespace.

    For example:
       mix bonny.gen.manifest --image YOUR_DOCKER_IMAGE_NAME
       mix bonny.gen.manifest --image YOUR_DOCKER_IMAGE_NAME --namespace prod
    """)
  end
end
