# Testing

If you're writing tests, you might also want to check out the [`k8s` library testing guide](https://hexdocs.pm/k8s/testing.html).

## Integration Testing

A `Makefile` is included for help with integration testing against k3d. You're gonna need k3d installed on your machine to run integration tests.

Run `make help` for a list of commands:

```
test.integration               Run integration tests using k3d `make cluster`
test.watch                     Run all tests with mix.watch
test                           Run all tests
```

### Integration environment variables

- `TEST_KUBECONFIG` path to kubeconfig file for integration tests, default: "./integration.yaml"
