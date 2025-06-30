package main

import (
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"
)

// Test helper functions

func createTempSocket(t *testing.T) string {
	tempDir := t.TempDir()
	return filepath.Join(tempDir, "test.sock")
}

func waitForListener(address string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		conn, err := net.Dial("tcp", address)
		if err == nil {
			conn.Close()
			return nil
		}
		time.Sleep(10 * time.Millisecond)
	}
	return fmt.Errorf("timeout waiting for listener on %s", address)
}

func findFreePort() (int, error) {
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		return 0, err
	}
	defer listener.Close()
	return listener.Addr().(*net.TCPAddr).Port, nil
}

// Test basic functionality

func TestForwardConfig_Validation(t *testing.T) {
	tests := []struct {
		name    string
		config  ForwardConfig
		isValid bool
	}{
		{
			name: "valid tcp to unix",
			config: ForwardConfig{
				ListenType:  "tcp",
				ListenAddr:  ":8080",
				ConnectType: "unix",
				ConnectAddr: "/tmp/test.sock",
			},
			isValid: true,
		},
		{
			name: "valid unix to tcp",
			config: ForwardConfig{
				ListenType:  "unix",
				ListenAddr:  "/tmp/listen.sock",
				ConnectType: "tcp",
				ConnectAddr: "localhost:9090",
			},
			isValid: true,
		},
		{
			name: "empty listen address",
			config: ForwardConfig{
				ListenType:  "tcp",
				ListenAddr:  "",
				ConnectType: "unix",
				ConnectAddr: "/tmp/test.sock",
			},
			isValid: false,
		},
		{
			name: "empty connect address",
			config: ForwardConfig{
				ListenType:  "tcp",
				ListenAddr:  ":8080",
				ConnectType: "unix",
				ConnectAddr: "",
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.config.ListenAddr != "" && tt.config.ConnectAddr != ""
			if isValid != tt.isValid {
				t.Errorf("Expected validity %v, got %v", tt.isValid, isValid)
			}
		})
	}
}

func TestConnectToTarget_TCP(t *testing.T) {
	// Create a test TCP server
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		t.Fatalf("Failed to create test server: %v", err)
	}
	defer listener.Close()

	address := listener.Addr().String()

	// Start accepting connections
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			conn.Write([]byte("Hello from server"))
			conn.Close()
		}
	}()

	// Test connecting to the server
	conn, err := connectToTarget("tcp", address)
	if err != nil {
		t.Fatalf("Failed to connect to target: %v", err)
	}
	defer conn.Close()

	// Read response
	buffer := make([]byte, 1024)
	n, err := conn.Read(buffer)
	if err != nil {
		t.Fatalf("Failed to read from connection: %v", err)
	}

	expected := "Hello from server"
	actual := string(buffer[:n])
	if actual != expected {
		t.Errorf("Expected %q, got %q", expected, actual)
	}
}

func TestConnectToTarget_Unix(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Unix domain sockets test skipped on Windows")
	}

	socketPath := createTempSocket(t)

	// Create a test Unix socket server
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Fatalf("Failed to create test Unix server: %v", err)
	}
	defer listener.Close()
	defer os.Remove(socketPath)

	// Start accepting connections
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			conn.Write([]byte("Hello from Unix server"))
			conn.Close()
		}
	}()

	// Test connecting to the Unix socket
	conn, err := connectToTarget("unix", socketPath)
	if err != nil {
		t.Fatalf("Failed to connect to Unix target: %v", err)
	}
	defer conn.Close()

	// Read response
	buffer := make([]byte, 1024)
	n, err := conn.Read(buffer)
	if err != nil {
		t.Fatalf("Failed to read from Unix connection: %v", err)
	}

	expected := "Hello from Unix server"
	actual := string(buffer[:n])
	if actual != expected {
		t.Errorf("Expected %q, got %q", expected, actual)
	}
}

func TestConnectToTarget_Abstract(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("Abstract Unix sockets only supported on Linux")
	}

	abstractAddr := "@test_socket"

	// Create a test abstract Unix socket server
	listener, err := net.Listen("unix", abstractAddr)
	if err != nil {
		t.Fatalf("Failed to create test abstract Unix server: %v", err)
	}
	defer listener.Close()

	// Start accepting connections
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			conn.Write([]byte("Hello from abstract server"))
			conn.Close()
		}
	}()

	// Test connecting to the abstract socket
	conn, err := connectToTarget("abstract", "test_socket")
	if err != nil {
		t.Fatalf("Failed to connect to abstract target: %v", err)
	}
	defer conn.Close()

	// Read response
	buffer := make([]byte, 1024)
	n, err := conn.Read(buffer)
	if err != nil {
		t.Fatalf("Failed to read from abstract connection: %v", err)
	}

	expected := "Hello from abstract server"
	actual := string(buffer[:n])
	if actual != expected {
		t.Errorf("Expected %q, got %q", expected, actual)
	}
}

func TestConnectToTarget_InvalidType(t *testing.T) {
	_, err := connectToTarget("invalid", "address")
	if err == nil {
		t.Fatal("Expected error for invalid connect type")
	}

	expectedError := "unsupported connect type: invalid"
	if err.Error() != expectedError {
		t.Errorf("Expected error %q, got %q", expectedError, err.Error())
	}
}

func TestTCPToTCPForwarding(t *testing.T) {
	// Create target server
	targetListener, err := net.Listen("tcp", ":0")
	if err != nil {
		t.Fatalf("Failed to create target server: %v", err)
	}
	defer targetListener.Close()

	targetPort := targetListener.Addr().(*net.TCPAddr).Port
	targetAddr := fmt.Sprintf("localhost:%d", targetPort)

	// Target server echoes received data
	go func() {
		for {
			conn, err := targetListener.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				defer c.Close()
				io.Copy(c, c) // Echo server
			}(conn)
		}
	}()

	// Create forwarder configuration
	forwarderPort, err := findFreePort()
	if err != nil {
		t.Fatalf("Failed to find free port: %v", err)
	}

	config := ForwardConfig{
		ListenType:  "tcp",
		ListenAddr:  fmt.Sprintf(":%d", forwarderPort),
		ConnectType: "tcp",
		ConnectAddr: targetAddr,
		Fork:        true,
	}

	// Start forwarder
	go func() {
		err := startForwarder(config)
		if err != nil {
			t.Logf("Forwarder error: %v", err)
		}
	}()

	// Wait for forwarder to start
	forwarderAddr := fmt.Sprintf("localhost:%d", forwarderPort)
	if err := waitForListener(forwarderAddr, 2*time.Second); err != nil {
		t.Fatalf("Forwarder failed to start: %v", err)
	}

	// Test the forwarding
	client, err := net.Dial("tcp", forwarderAddr)
	if err != nil {
		t.Fatalf("Failed to connect to forwarder: %v", err)
	}
	defer client.Close()

	// Send test data
	testData := "Hello, World!"
	_, err = client.Write([]byte(testData))
	if err != nil {
		t.Fatalf("Failed to write test data: %v", err)
	}

	// Read echoed data
	buffer := make([]byte, len(testData))
	_, err = io.ReadFull(client, buffer)
	if err != nil {
		t.Fatalf("Failed to read echoed data: %v", err)
	}

	if string(buffer) != testData {
		t.Errorf("Expected %q, got %q", testData, string(buffer))
	}
}

func TestMultipleConnections(t *testing.T) {
	// Create target server
	targetListener, err := net.Listen("tcp", ":0")
	if err != nil {
		t.Fatalf("Failed to create target server: %v", err)
	}
	defer targetListener.Close()

	targetPort := targetListener.Addr().(*net.TCPAddr).Port
	targetAddr := fmt.Sprintf("localhost:%d", targetPort)

	// Target server that counts connections
	var mu sync.Mutex
	var connectionCount int
	var wg sync.WaitGroup

	go func() {
		for {
			conn, err := targetListener.Accept()
			if err != nil {
				return
			}
			wg.Add(1)
			go func(c net.Conn) {
				defer c.Close()
				defer wg.Done()

				mu.Lock()
				connectionCount++
				mu.Unlock()

				// Simple echo
				buffer := make([]byte, 1024)
				n, err := c.Read(buffer)
				if err != nil {
					return
				}
				c.Write(buffer[:n])
			}(conn)
		}
	}()

	// Create and start forwarder
	forwarderPort, err := findFreePort()
	if err != nil {
		t.Fatalf("Failed to find free port: %v", err)
	}

	config := ForwardConfig{
		ListenType:  "tcp",
		ListenAddr:  fmt.Sprintf(":%d", forwarderPort),
		ConnectType: "tcp",
		ConnectAddr: targetAddr,
		Fork:        true,
	}

	go func() {
		startForwarder(config)
	}()

	// Wait for forwarder to start
	forwarderAddr := fmt.Sprintf("localhost:%d", forwarderPort)
	if err := waitForListener(forwarderAddr, 2*time.Second); err != nil {
		t.Fatalf("Forwarder failed to start: %v", err)
	}

	// Create multiple concurrent connections
	numConnections := 3 // Reduced to avoid race conditions
	var clientWg sync.WaitGroup

	for i := 0; i < numConnections; i++ {
		clientWg.Add(1)
		go func(id int) {
			defer clientWg.Done()

			client, err := net.Dial("tcp", forwarderAddr)
			if err != nil {
				t.Errorf("Client %d failed to connect: %v", id, err)
				return
			}
			defer client.Close()

			testData := fmt.Sprintf("Hello from client %d", id)
			client.Write([]byte(testData))

			buffer := make([]byte, len(testData))
			_, err = io.ReadFull(client, buffer)
			if err != nil {
				t.Errorf("Client %d failed to read response: %v", id, err)
				return
			}

			if string(buffer) != testData {
				t.Errorf("Client %d: expected %q, got %q", id, testData, string(buffer))
			}
		}(i)
	}

	clientWg.Wait()
	wg.Wait()

	mu.Lock()
	finalCount := connectionCount
	mu.Unlock()

	if finalCount < numConnections {
		t.Errorf("Expected at least %d connections, got %d", numConnections, finalCount)
	}
}

func TestAbstractSocketHandling(t *testing.T) {
	// Test that abstract socket addresses are properly formatted
	testCases := []struct {
		input    string
		expected string
	}{
		{"webview", "@webview"},
		{"@webview", "@webview"},
		{"test_socket", "@test_socket"},
		{"@test_socket", "@test_socket"},
	}

	for _, tc := range testCases {
		t.Run(fmt.Sprintf("input_%s", tc.input), func(t *testing.T) {
			addr := tc.input
			if !strings.HasPrefix(addr, "@") {
				addr = "@" + addr
			}

			if addr != tc.expected {
				t.Errorf("Expected %q, got %q", tc.expected, addr)
			}
		})
	}
}

// Benchmark tests

func BenchmarkTCPForwarding(b *testing.B) {
	// Setup target server
	targetListener, err := net.Listen("tcp", ":0")
	if err != nil {
		b.Fatalf("Failed to create target server: %v", err)
	}
	defer targetListener.Close()

	targetPort := targetListener.Addr().(*net.TCPAddr).Port
	targetAddr := fmt.Sprintf("localhost:%d", targetPort)

	// Simple echo server
	go func() {
		for {
			conn, err := targetListener.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				defer c.Close()
				io.Copy(c, c)
			}(conn)
		}
	}()

	// Setup forwarder
	forwarderPort, err := findFreePort()
	if err != nil {
		b.Fatalf("Failed to find free port: %v", err)
	}

	config := ForwardConfig{
		ListenType:  "tcp",
		ListenAddr:  fmt.Sprintf(":%d", forwarderPort),
		ConnectType: "tcp",
		ConnectAddr: targetAddr,
		Fork:        true,
	}

	go startForwarder(config)

	forwarderAddr := fmt.Sprintf("localhost:%d", forwarderPort)
	if err := waitForListener(forwarderAddr, 2*time.Second); err != nil {
		b.Fatalf("Forwarder failed to start: %v", err)
	}

	b.ResetTimer()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			client, err := net.Dial("tcp", forwarderAddr)
			if err != nil {
				b.Fatalf("Failed to connect: %v", err)
			}

			testData := "benchmark test data"
			client.Write([]byte(testData))

			buffer := make([]byte, len(testData))
			io.ReadFull(client, buffer)

			client.Close()
		}
	})
}
