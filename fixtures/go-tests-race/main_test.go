package main

import (
	"sync"
	"testing"
)

// TestRace has an unsynchronised write to a shared variable across goroutines.
// It passes under `go test` but is flagged by `go test -race` (exit 1), so it
// proves the central Go test path actually enables the race detector.
func TestRace(t *testing.T) {
	var x int
	var wg sync.WaitGroup
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			x++ // data race: concurrent unsynchronised write
		}()
	}
	wg.Wait()
	_ = x
}
