# Each test restarts the application, so the first push also opens a new HTTP connection;
# the default 100ms is too tight for that on slow machines.
ExUnit.start(assert_receive_timeout: 1_000)
