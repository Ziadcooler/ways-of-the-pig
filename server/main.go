package main

import (
	"fmt"
	"net"
	"sync"
)

func main() {
	ln, err := net.Listen("tcp", ":9000")
	if err != nil {
		panic(err)
	}
	fmt.Println("Server running on tcp port 9000")

	for {
		conn, err := ln.Accept()
		if err != nil {
			continue
		}
		go handleConnection(conn)
	}
}

var (
	clients = make(map[net.Conn]bool)
	mu      sync.Mutex
)

func handleConnection(conn net.Conn) {
	defer func() {
		mu.Lock()
		delete(clients, conn)
		mu.Unlock()
		conn.Close()
		fmt.Printf("Client disconnected: %s\n", conn.RemoteAddr())
	}()

	mu.Lock()
	clients[conn] = true
	mu.Unlock()

	fmt.Printf("New connection from %s\n", conn.RemoteAddr())

	buf := make([]byte, 1024)
	for {
		n, err := conn.Read(buf)
		if err != nil {
			return
		}
		msg := string(buf[:n])
		fmt.Printf("Message from %s: %s\n", conn.RemoteAddr(), msg)

		// broadcast to all
		mu.Lock()
		for c := range clients {
			if c != conn {
				c.Write([]byte(msg))
			}
		}
		mu.Unlock()
	}
}
