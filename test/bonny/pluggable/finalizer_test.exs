defmodule Bonny.Pluggable.FinalizerTest do
  use ExUnit.Case, async: true
  use Bonny.Axn.Test

  alias Bonny.Pluggable.Finalizer, as: MUT

  defmodule FinalizerK8sMock do
    require Logger
    import K8s.Client.HTTPTestHelper

    def request(
          :patch,
          %URI{path: "api/v1/namespaces/default/configmaps/foo"},
          body,
          _headers,
          _opts
        ) do
      resource = Jason.decode!(body)
      render(resource)
    end

    def request(_method, _uri, _body, _headers, _opts) do
      Logger.error("Call to #{__MODULE__}.request/5 not handled: #{inspect(binding())}")
      {:error, %K8s.Client.HTTPError{message: "request not mocked"}}
    end
  end

  setup do
    K8s.Client.DynamicHTTPProvider.register(self(), FinalizerK8sMock)
  end

  test "adds finalizer to resource metadata" do
    opts =
      MUT.init(id: "bonny/foo-finalizer", impl: fn axn -> {:ok, axn} end, add_to_resource: true)

    axn = MUT.call(axn(:add), opts)
    assert [resource] = Map.values(axn.descendants)
    assert "bonny/foo-finalizer" in resource["metadata"]["finalizers"]
  end

  test "skips adding finalizer to resource metadata if add_to_resource evals to false" do
    opts =
      MUT.init(
        id: "bonny/foo-finalizer",
        impl: fn axn -> {:ok, axn} end,
        add_to_resource: fn _ -> false end
      )

    axn = MUT.call(axn(:add), opts)
    assert %{} = axn.descendants
  end

  test "Noop if finalizer already in resource metadata" do
    opts =
      MUT.init(id: "bonny/foo-finalizer", impl: fn axn -> {:ok, axn} end, add_to_resource: true)

    axn = axn(:add)

    axn = put_in(axn.resource["metadata"]["finalizers"], ["bonny/foo-finalizer"])

    result = MUT.call(axn, opts)
    assert %{} == result.descendants
  end

  test "Calls finalizer when deletionTimestamp is set" do
    ref = make_ref()

    impl = fn axn ->
      send(self(), {ref, :called})
      {:ok, axn}
    end

    opts = MUT.init(id: "bonny/foo-finalizer", impl: impl)

    axn = axn(:add)
    # add finalizer
    axn = put_in(axn.resource["metadata"]["finalizers"], ["bonny/foo-finalizer"])
    # set deletionTimestamp
    axn = put_in(axn.resource["metadata"]["deletionTimestamp"], DateTime.utc_now())
    # call finalizer
    axn = MUT.call(axn, opts)

    assert_receive {^ref, :called}
    assert "bonny/foo-finalizer" not in axn.resource["metadata"]["finalizers"]
    assert axn.halted
  end

  test "Halts when deletionTimestamp is set" do
    ref = make_ref()

    impl = fn axn ->
      send(self(), {ref, :called})
      axn
    end

    opts = MUT.init(id: "bonny/foo-finalizer", impl: impl)

    axn = axn(:add)
    # set deletionTimestamp
    axn = put_in(axn.resource["metadata"]["deletionTimestamp"], DateTime.utc_now())
    # call finalizer
    axn = MUT.call(axn, opts)

    refute_receive {^ref, :called}
    assert axn.halted
  end
end
