defmodule Bonny.API.ResourceEndpoint do
  @moduledoc """
  Defines the API Endpoint for a Kubernetes resource.

  The struct contains the fields `group`, `resource_type`, `scope` and `version`.
  New definitions can be created directly or using the `new!/1` function.
  """

  @typedoc """
  A Resource API Definition. Also see [Kubernetes API terminology](https://kubernetes.io/docs/reference/using-api/api-concepts/#standard-api-terminology).

  * `group`: The API group used for REST API: /apis/<group>/<version>, e.g. "apps" or "example.com"
  * `resource_type`: The plural form of the resource name
  * `scope`: `:Namespaced` or `:Cluster` - defaults to `:Namespaced`
  * `version`: The API version used for REST API: /apis/<group>/<version>, e.g. "v1" or "v1alpha1"
  """
  @type t :: %__MODULE__{
          group: binary() | nil,
          resource_type: binary(),
          scope: :Namespaced | :Cluster,
          version: binary()
        }

  defstruct [:group, :resource_type, :version, scope: :Namespaced]

  @doc """
  Creates a new %Bonny.API.ResourceEndpoint{} struct from the given values. `:scope` is
  optional and defaults to `:Namespaced`.
  """
  @spec new!(keyword()) :: __MODULE__.t()
  def new!(fields) do
    struct!(__MODULE__, fields)
  end

  @doc """
  Creates a new %Bonny.API.ResourceEndpoint{} struct from `apiVersion` and `kind`.
  The scope can be passed as a third optional parameter.

  ### Examples

      iex> Bonny.API.ResourceEndpoint.new!("apps/v1", "Deployment")
      %Bonny.API.ResourceEndpoint{group: "apps", resource_type: "deployments", scope: :Namespaced, version: "v1"}

      iex> Bonny.API.ResourceEndpoint.new!("v1", "Pod")
      %Bonny.API.ResourceEndpoint{group: nil, resource_type: "pods", scope: :Namespaced, version: "v1"}

      iex> Bonny.API.ResourceEndpoint.new!("rbac.authorization.k8s.io/v1", "ClusterRoleBinding", :Cluster)
      %Bonny.API.ResourceEndpoint{group: "rbac.authorization.k8s.io", resource_type: "clusterrolebindings", scope: :Cluster, version: "v1"}

      iex> Bonny.API.ResourceEndpoint.new!("foo/bar/v1", "ClusterRoleBinding", :Cluster)
      ** (ArgumentError) The api_version "foo/bar/v1" cannot be parsed. It contains more than one slash (/).
  """
  @spec new!(binary(), binary(), :Namespaced | :Cluster) :: t()
  def new!(api_version, kind, scope \\ :Namespaced) do
    resource_type = kind |> String.downcase() |> Inflex.pluralize()

    {group, version} =
      case String.split(api_version, "/") do
        [group, version] ->
          {group, version}

        [version] ->
          {nil, version}

        _ ->
          raise ArgumentError,
            message:
              "The api_version #{inspect(api_version)} cannot be parsed. It contains more than one slash (/)."
      end

    struct!(
      __MODULE__,
      group: group,
      resource_type: resource_type,
      scope: scope,
      version: version
    )
  end

  @doc """
  Gets apiVersion of the actual resources.

  ## Examples
    Returns apiVersion for an operator

      iex> Bonny.API.ResourceEndpoint.resource_api_version(%Bonny.API.ResourceEndpoint{group: "hello.example.com", version: "v1", scope: :namespaced, resource_type: "foos"})
      "hello.example.com/v1"

    Returns apiVersion for `apps` resources

      iex> Bonny.API.ResourceEndpoint.resource_api_version(%Bonny.API.ResourceEndpoint{group: "apps", version: "v1", scope: :namespaced, resource_type: "foos"})
      "apps/v1"

    Returns apiVersion for `core` resources

      iex> Bonny.API.ResourceEndpoint.resource_api_version(%Bonny.API.ResourceEndpoint{group: "", version: "v1", scope: :namespaced, resource_type: "foos"})
      "v1"

      iex> Bonny.API.ResourceEndpoint.resource_api_version(%Bonny.API.ResourceEndpoint{group: nil, version: "v1", scope: :namespaced, resource_type: "foos"})
      "v1"
  """
  @spec resource_api_version(t()) :: String.t()
  def resource_api_version(definition),
    do: api_group_prefix(definition) <> definition.version

  defp api_group_prefix(%__MODULE__{group: ""}), do: ""
  defp api_group_prefix(%__MODULE__{group: nil}), do: ""
  defp api_group_prefix(%__MODULE__{group: g}), do: "#{g}/"
end
