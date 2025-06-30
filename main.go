package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

type ForwardConfig struct {
	ListenType  string
	ListenAddr  string
	ConnectType string
	ConnectAddr string
	Fork        bool
}

func main() {
	var config ForwardConfig

	flag.StringVar(&config.ListenType, "listen-type", "tcp", "Listen type: tcp, unix")
	flag.StringVar(&config.ListenAddr, "listen-addr", "", "Listen address")
	flag.StringVar(&config.ConnectType, "connect-type", "unix", "Connect type: tcp, unix, abstract")
	flag.StringVar(&config.ConnectAddr, "connect-addr", "", "Connect address")
	flag.BoolVar(&config.Fork, "fork", true, "Fork connections (handle multiple concurrent connections)")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nSocket Forwarder - Forward data between different socket types\n\n")
		fmt.Fprintf(os.Stderr, "Examples:\n")
		fmt.Fprintf(os.Stderr, "  %s -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -listen-type tcp -listen-addr :8080 -connect-type unix -connect-addr /tmp/socket\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -listen-type unix -listen-addr /tmp/listen.sock -connect-type tcp -connect-addr localhost:9090\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nOptions:\n")
		flag.PrintDefaults()
	}

	flag.Parse()

	if config.ListenAddr == "" || config.ConnectAddr == "" {
		flag.Usage()
		os.Exit(1)
	}

	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	log.Printf("Starting socket forwarder: %s:%s -> %s:%s",
		config.ListenType, config.ListenAddr,
		config.ConnectType, config.ConnectAddr)

	// Start the forwarder
	go func() {
		if err := startForwarder(config); err != nil {
			log.Fatalf("Forwarder error: %v", err)
		}
	}()

	// Wait for shutdown signal
	<-sigChan
	log.Println("Shutting down...")
}

func startForwarder(config ForwardConfig) error {
	var listener net.Listener
	var err error

	// Create listener based on type
	switch config.ListenType {
	case "tcp":
		listener, err = net.Listen("tcp", config.ListenAddr)
	case "unix":
		// Remove existing socket file if it exists
		if _, err := os.Stat(config.ListenAddr); err == nil {
			os.Remove(config.ListenAddr)
		}
		listener, err = net.Listen("unix", config.ListenAddr)
	default:
		return fmt.Errorf("unsupported listen type: %s", config.ListenType)
	}

	if err != nil {
		return fmt.Errorf("failed to create listener: %v", err)
	}
	defer listener.Close()

	log.Printf("Listening on %s:%s", config.ListenType, config.ListenAddr)

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Accept error: %v", err)
			continue
		}

		if config.Fork {
			go handleConnection(conn, config)
		} else {
			handleConnection(conn, config)
		}
	}
}

func handleConnection(clientConn net.Conn, config ForwardConfig) {
	defer clientConn.Close()

	clientAddr := clientConn.RemoteAddr().String()
	log.Printf("New connection from %s", clientAddr)

	// Connect to target
	targetConn, err := connectToTarget(config.ConnectType, config.ConnectAddr)
	if err != nil {
		log.Printf("Failed to connect to target %s:%s: %v",
			config.ConnectType, config.ConnectAddr, err)
		return
	}
	defer targetConn.Close()

	log.Printf("Connected to target %s:%s", config.ConnectType, config.ConnectAddr)

	// Start bidirectional forwarding
	done := make(chan struct{}, 2)

	// Forward from client to target
	go func() {
		defer func() { done <- struct{}{} }()
		bytes, err := io.Copy(targetConn, clientConn)
		if err != nil {
			log.Printf("Client->Target copy error: %v", err)
		} else {
			log.Printf("Client->Target: %d bytes forwarded", bytes)
		}
	}()

	// Forward from target to client
	go func() {
		defer func() { done <- struct{}{} }()
		bytes, err := io.Copy(clientConn, targetConn)
		if err != nil {
			log.Printf("Target->Client copy error: %v", err)
		} else {
			log.Printf("Target->Client: %d bytes forwarded", bytes)
		}
	}()

	// Wait for either direction to complete
	<-done
	log.Printf("Connection from %s closed", clientAddr)
}

func connectToTarget(connectType, connectAddr string) (net.Conn, error) {
	var conn net.Conn
	var err error

	switch connectType {
	case "tcp":
		conn, err = net.DialTimeout("tcp", connectAddr, 10*time.Second)
	case "unix":
		conn, err = net.DialTimeout("unix", connectAddr, 10*time.Second)
	case "abstract":
		// Abstract Unix domain sockets (Linux specific)
		// On Windows, this will fall back to regular unix socket
		addr := connectAddr
		if !strings.HasPrefix(addr, "@") {
			addr = "@" + addr
		}
		conn, err = net.DialTimeout("unix", addr, 10*time.Second)
	default:
		return nil, fmt.Errorf("unsupported connect type: %s", connectType)
	}

	return conn, err
}
