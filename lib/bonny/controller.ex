defmodule Bonny.Controller do
  @moduledoc """
  `Bonny.Controller` defines controller behaviours and generates boilerplate for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile` handling of custom resources in the Kubernetes API.
  """

  @callback add(map()) :: :ok | :error
  @callback modify(map()) :: :ok | :error
  @callback delete(map()) :: :ok | :error
  @callback reconcile(map()) :: :ok | :error

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Bonny.Controller
      Module.register_attribute(__MODULE__, :rule, accumulate: true)
      @behaviour Bonny.Controller
      @group nil
      @version nil
      @scope nil
      @names nil
      @additional_printer_columns nil
      @before_compile Bonny.Controller
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Kubernetes CRD manifest spec
      """
      @spec crd_spec() :: Bonny.CRD.t()
      def crd_spec do
        kind = Bonny.Naming.module_to_kind(__MODULE__)
        version = Bonny.Naming.module_version(__MODULE__)

        %Bonny.CRD{
          group: @group || Bonny.Config.group(),
          scope: @scope || :namespaced,
          version: @version || version,
          additionalPrinterColumns: additional_printer_columns(),
          names: crd_spec_names(@names, kind)
        }
      end

      @doc """
      Kubernetes RBAC rules
      """
      def rules() do
        Enum.reduce(@rule, [], fn {api, resources, verbs}, acc ->
          rule = %{
            apiGroups: [api],
            resources: resources,
            verbs: verbs
          }

          [rule | acc]
        end)
      end

      defp additional_printer_columns() do
        case @additional_printer_columns do
          nil ->
            nil

          some ->
            some ++ Bonny.Controller.default_columns()
        end
      end

      @spec crd_spec_names(nil | map, String.t()) :: map
      defp crd_spec_names(nil, kind), do: crd_spec_names(%{}, kind)

      defp crd_spec_names(%{} = names, default_kind) do
        kind = names[:kind] || default_kind
        singular = Macro.underscore(kind)

        defaults = %{
          plural: "#{singular}s",
          singular: singular,
          kind: kind,
          shortNames: nil
        }

        Map.merge(defaults, names)
      end
    end
  end

  @doc """
  Columns default
  """
  def default_columns() do
    [
      %{
        name: "Age",
        type: "date",
        description:
          "CreationTimestamp is a timestamp representing the server time when this object was created. It is not guaranteed to be set in happens-before order across separate operations. Clients may not set this value. It is represented in RFC3339 form and is in UTC.

      Populated by the system. Read-only. Null for lists. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata",
        JSONPath: ".metadata.creationTimestamp"
      }
    ]
  end
end
