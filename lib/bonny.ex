defmodule Bonny do
  @moduledoc """
  Documentation for Bonny.
  """

  @doc """
  The namespace to watch for `Namespaced` CRDs.
  """
  @spec namespace() :: binary
  def namespace() do
    Application.get_env(:bonny, :override_namespace) || System.get_env("BONNY_POD_NAMESPACE") ||
      "default"
  end

  @doc """
  `K8s.Conf` configuration. This is used to sign HTTP requests to the Kubernetes API.

  Bonny defaults to the service account of the pod if a cluster configuration is not provided.
  """
  def kubeconfig() do
    case config_path() do
      conf_path when is_binary(conf_path) ->
        conf_opts = Application.get_env(:bonny, :kubeconf_opts, [])
        K8s.Conf.from_file(conf_path, conf_opts)

      _ ->
        K8s.Conf.from_service_account()
    end
  end

  @doc """
  Kubernetes API Group of this operator
  """
  @spec group() :: binary
  def group do
    Application.get_env(:bonny, :group)
  end

  @doc """
  Kubernetes service account name to run operator as.

  Name must consist of only lowercase letters and hyphens.

  Defaults to operator name.
  """
  @spec service_account() :: binary
  def service_account() do
    service_account_name = Application.get_env(:bonny, :service_account_name, Bonny.name())

    service_account_name
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
  end

  @doc """
  Labels to apply to all operator resources.

  *Note:* These are only applied to the resoures that compose the operator itself,
  not the resources created by the operator.
  """
  @spec labels() :: map()
  def labels() do
    Application.get_env(:bonny, :labels, %{})
  end

  @doc """
  The name of the operator.

  Name must consist of only lowercase letters and hyphens.

  Defaults to "bonny"
  """
  @spec name() :: binary
  def name() do
    operator_name = Application.get_env(:bonny, :operator_name, "bonny")

    operator_name
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
  end

  @doc "List of all enabled controller modules"
  @spec controllers() :: list(atom)
  def controllers(), do: Application.get_env(:bonny, :controllers, [])

  defp config_path do
    System.get_env("BONNY_CONFIG_FILE") || Application.get_env(:bonny, :kubeconf_file)
  end
end
