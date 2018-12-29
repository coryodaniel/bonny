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
    operator_name = Application.get_env(:bonny, :operator_name, project_name())

    operator_name
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
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
    service_account_name = Application.get_env(:bonny, :service_account_name, project_name())

    service_account_name
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
  end

  defp project_name() do
    Mix.Project.config()
    |> Keyword.fetch!(:app)
    |> Atom.to_string()
    |> String.replace("_", "-")
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

  Defaults to all implementations of Bonny.Controller.

  This can be set in config.exs:

  ```
  config :bonny, controllers: [MyController1, MyController2]
  ```
  """
  @spec controllers() :: list(atom)
  def controllers() do
    default_controllers =
      :code.all_loaded()
      |> Enum.filter(fn {mod, _} ->
        behaviours = mod.module_info(:attributes)[:behaviour]
        behaviours && Enum.member?(behaviours, Bonny.Controller)
      end)
      |> Enum.map(&elem(&1, 0))

    Application.get_env(:bonny, :controllers, default_controllers)
  end

  @doc """
  The namespace to watch for `Namespaced` CRDs.

  Defaults to `default`

  This can be set via environment variable:

  ```shell
  BONNY_POD_NAMESPACE=prod
  iex -S mix
  ```

  Bonny sets `BONNY_POD_NAMESPACE` on all Kubernetes deployments to the namespace the operator is deployed in.
  """
  @spec namespace() :: binary
  def namespace() do
    System.get_env("BONNY_POD_NAMESPACE") || "default"
  end

  @doc """
  `K8s.Conf` configuration. This is used to sign HTTP requests to the Kubernetes API.

  Bonny defaults to the service account of the pod if a cluster configuration is not provided.
  """
  def kubeconfig() do
    config_path =
      System.get_env("BONNY_CONFIG_FILE") || Application.get_env(:bonny, :kubeconf_file)

    case config_path do
      conf_path when is_binary(conf_path) ->
        conf_opts = Application.get_env(:bonny, :kubeconf_opts, [])
        K8s.Conf.from_file(conf_path, conf_opts)

      _ ->
        K8s.Conf.from_service_account()
    end
  end
end
