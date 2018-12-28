workflow "Run tests" {
  on = "push"
  resolves = ["docker run"]
}

action "docker build" {
  uses = "actions/docker/cli@76ff57a"
  runs = "build -t bonny:test ."
}

action "docker run" {
  uses = "actions/docker/cli@76ff57a"
  needs = ["docker build"]
  runs = "run bonny:test"
}
