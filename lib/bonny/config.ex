defmodule Bonny.Config do
  @moduledoc """
  Operator configuration interface
  """

  @doc """
  Kubernetes API Group of this operator
  """
  @spec group() :: binary
  def group do
    default = "#{project_name()}.example.com"
    Application.get_env(:bonny, :group, default)
  end

  @doc """
  The name of the operator.

  Name must consist of only lowercase letters and hyphens.

  Defaults to hyphenated mix project app name. E.g.: `:hello_operator` becomes `hello-operator`
  """
  @spec name() :: binary
  def name() do
    :bonny
    |> Application.get_env(:operator_name, project_name())
    |> dns_safe_name
  end

  @doc """
  Kubernetes service account name to run operator as.

  *Note:* if a kube config file is provided, this service account will still be created
  and assigned to pods, but the *config file auth will be used* when making requests to the Kube API.

  Name must consist of only lowercase letters and hyphens.

  Defaults to hyphenated mix project app name. E.g.: `:hello_operator` becomes `hello-operator`
  """
  @spec service_account() :: binary
  def service_account() do
    :bonny
    |> Application.get_env(:service_account_name, project_name())
    |> dns_safe_name
  end

  defp project_name() do
    Mix.Project.config()
    |> Keyword.fetch!(:app)
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp dns_safe_name(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
  end

  @doc """
  Labels to apply to all operator resources.

  *Note:* These are only applied to the resoures that compose the operator itself,
  not the resources created by the operator.

  This can be set in config.exs:

  ```
  config :bonny, labels: %{foo: "bar", quz: "baz"}
  ```

  """
  @spec labels() :: map()
  def labels() do
    Application.get_env(:bonny, :labels, %{})
  end

  @doc """
  List of all controller modules to watch.

  This *must* be set in config.exs:

  ```
  config :bonny, controllers: [MyController1, MyController2]
  ```
  """
  @spec controllers() :: list(atom)
  def controllers() do
    Application.get_env(:bonny, :controllers, [])
  end

  @doc """
  The namespace to watch for `Namespaced` CRDs.

  Defaults to `default`

  This can be set via environment variable:

  ```shell
  BONNY_POD_NAMESPACE=prod # specific namespace
  # or
  BONNY_POD_NAMESPACE=__ALL__ # all namespaces
  iex -S mix
  ```

  Or via config.exs:
  ```
  config :bonny, namespace: "mynamespace" # specific namespace
  # or
  config :bonny; namespace: :all # all namespaces
  ```

  Configuration via environment variable always takes precedence over config.exs.

  Bonny sets `BONNY_POD_NAMESPACE` on all Kubernetes deployments to the namespace the operator is deployed in.
  """
  @spec namespace() :: binary
  def namespace() do
    case System.get_env("BONNY_POD_NAMESPACE") do
      nil -> Application.get_env(:bonny, :namespace, "default")
      "__ALL__" -> :all
      namespace -> namespace
    end
  end

  @doc """
  `K8s.Cluster` name used for this operator. Defaults to `:default`
  """
  @spec cluster_name() :: atom
  def cluster_name() do
    Application.get_env(:bonny, :cluster_name, :default)
  end
end
