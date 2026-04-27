package config

import "os"

// Thin os-package shims so config_test.go can import only this package.
// Tests that mutate the process env share these wrappers — keeps the
// public API surface free of "os" imports.

func getenv(k string) string   { return os.Getenv(k) }
func setenv(k, v string) error { return os.Setenv(k, v) }
func unsetenv(k string) error  { return os.Unsetenv(k) }
